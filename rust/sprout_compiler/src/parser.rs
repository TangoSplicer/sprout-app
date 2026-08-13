use crate::ast::*;
use crate::SproutError;
use anyhow::Result;
use regex::Regex;
use std::collections::HashMap;

pub struct Parser {
    source: String,
    variables: HashMap<String, ValueType>,
}

impl Parser {
    pub fn new(source: &str) -> Self {
        Self {
            source: source.to_string(),
            variables: HashMap::new(),
        }
    }

    pub fn parse(&mut self) -> Result<App> {
        let (name, declared_start) = self.parse_app_declaration()?;
        let screen_blocks = extract_named_blocks(&self.source, "screen");
        if screen_blocks.is_empty() {
            return Err(SproutError::Parse("At least one screen is required".to_string()).into());
        }

        let mut screens = Vec::with_capacity(screen_blocks.len());
        for (screen_name, screen_body) in screen_blocks {
            screens.push(self.parse_screen(&screen_name, &screen_body)?);
        }

        let start_screen = declared_start.unwrap_or_else(|| screens[0].name.clone());
        if !screens.iter().any(|screen| screen.name == start_screen) {
            return Err(
                SproutError::Parse(format!("Start screen not found: {start_screen}")).into(),
            );
        }

        let app = App {
            name,
            start_screen,
            screens,
            state: Vec::new(),
        };
        self.validate_ast(&app)?;
        Ok(app)
    }

    fn parse_app_declaration(&self) -> Result<(String, Option<String>)> {
        let app_regex = Regex::new(r#"app\s+"([^"]+)"(?:\s*\{)?"#).expect("static regex");
        let capture = app_regex
            .captures(&self.source)
            .ok_or_else(|| SproutError::Parse("App declaration not found".to_string()))?;
        let name = capture
            .get(1)
            .expect("app name capture")
            .as_str()
            .to_string();

        if name.len() > App::MAX_NAME_LENGTH {
            return Err(SproutError::Security("App name too long".to_string()).into());
        }

        let start_regex =
            Regex::new(r#"(?m)^\s*start\s*=\s*"?([A-Za-z_]\w*)"?\s*$"#).expect("static regex");
        let start_screen = start_regex
            .captures(&self.source)
            .and_then(|capture| capture.get(1))
            .map(|capture| capture.as_str().to_string());

        Ok((name, start_screen))
    }

    fn parse_screen(&mut self, name: &str, body: &str) -> Result<Screen> {
        if name.len() > Screen::MAX_NAME_LENGTH {
            return Err(SproutError::Security("Screen name too long".to_string()).into());
        }

        let mut state = Vec::new();
        let state_regex =
            Regex::new(r"(?m)^\s*state\s+(\w+)\s*:\s*(.+?)\s*$").expect("static regex");
        for capture in state_regex.captures_iter(body) {
            let variable = capture
                .get(1)
                .expect("state variable capture")
                .as_str()
                .to_string();
            let value = self.parse_value(capture.get(2).expect("state value capture").as_str())?;
            self.variables.insert(variable.clone(), value.clone());
            state.push(StateVariable {
                name: variable,
                value,
            });
        }

        let ui_body = extract_keyword_block(body, "ui").unwrap_or_default();
        let ui = self.parse_ui_elements(&ui_body)?;
        Ok(Screen {
            name: name.to_string(),
            state,
            ui,
        })
    }

    fn parse_ui_elements(&mut self, ui_body: &str) -> Result<Vec<UiElement>> {
        let mut elements = Vec::new();
        let lines: Vec<&str> = ui_body.lines().collect();
        let label_regex = Regex::new(r#"^(?:label|title)\s+"([^"]*)"$"#).expect("static regex");
        let legacy_label_regex =
            Regex::new(r#"^(?:label|title)\("([^"]*)"\)$"#).expect("static regex");
        let input_regex = Regex::new(r#"^input\s+"([^"]+)"\s*->\s*(\w+)$"#).expect("static regex");
        let list_regex = Regex::new(r"^list\s+(\w+)$").expect("static regex");
        let button_regex = Regex::new(r#"^button\s+"([^"]+)"\s*(.*)$"#).expect("static regex");
        let legacy_button_regex = Regex::new(r#"^button\("([^"]+)"\)$"#).expect("static regex");

        let mut index = 0;
        while index < lines.len() {
            let line = lines[index].trim();
            index += 1;
            if line.is_empty()
                || line.starts_with("//")
                || line == "}"
                || matches!(line, "column {" | "row {")
            {
                continue;
            }

            if let Some(capture) = label_regex.captures(line) {
                let text = capture.get(1).expect("label capture").as_str();
                elements.push(UiElement::Label {
                    text: self.process_string_interpolation(text)?,
                });
                continue;
            }

            if let Some(capture) = legacy_label_regex.captures(line) {
                let text = capture.get(1).expect("label capture").as_str();
                elements.push(UiElement::Label {
                    text: self.process_string_interpolation(text)?,
                });
                continue;
            }

            if let Some(capture) = input_regex.captures(line) {
                elements.push(UiElement::TextField {
                    placeholder: capture.get(1).expect("input capture").as_str().to_string(),
                    bind_to: capture
                        .get(2)
                        .expect("binding capture")
                        .as_str()
                        .to_string(),
                });
                continue;
            }

            if let Some(capture) = list_regex.captures(line) {
                elements.push(UiElement::List {
                    items: Vec::new(),
                    bind_to: capture.get(1).expect("list capture").as_str().to_string(),
                });
                continue;
            }

            if let Some(capture) = legacy_button_regex.captures(line) {
                elements.push(UiElement::Button {
                    label: capture.get(1).expect("button capture").as_str().to_string(),
                    action: Action::Navigation {
                        target: String::new(),
                    },
                });
                continue;
            }

            if let Some(capture) = button_regex.captures(line) {
                let label = capture
                    .get(1)
                    .expect("button label capture")
                    .as_str()
                    .to_string();
                let remainder = capture.get(2).map_or("", |value| value.as_str()).trim();
                let action = if let Some(target) = remainder.strip_prefix("->") {
                    Action::Navigation {
                        target: target.trim().to_string(),
                    }
                } else if remainder.starts_with('{') {
                    let mut action_source = remainder.trim_start_matches('{').to_string();
                    let mut depth = brace_delta(remainder);
                    while depth > 0 && index < lines.len() {
                        let next = lines[index];
                        index += 1;
                        depth += brace_delta(next);
                        action_source.push('\n');
                        action_source.push_str(next);
                    }
                    if depth != 0 {
                        return Err(SproutError::Parse(format!(
                            "Unclosed action block for button: {label}"
                        ))
                        .into());
                    }
                    if let Some(closing) = action_source.rfind('}') {
                        action_source.truncate(closing);
                    }
                    self.parse_action_block(&action_source)?
                } else if remainder.is_empty() {
                    Action::Navigation {
                        target: String::new(),
                    }
                } else {
                    return Err(
                        SproutError::Parse(format!("Unsupported button syntax: {line}")).into(),
                    );
                };
                elements.push(UiElement::Button { label, action });
                continue;
            }

            return Err(SproutError::Parse(format!("Unsupported UI statement: {line}")).into());
        }

        Ok(elements)
    }

    fn parse_action_block(&self, source: &str) -> Result<Action> {
        let append_regex = Regex::new(r"^(\w+)\.append\((.+)\)$").expect("static regex");
        let remove_regex = Regex::new(r"^(\w+)\.remove\((.+)\)$").expect("static regex");
        let remove_first_regex = Regex::new(r"^(\w+)\.remove_first\(\)$").expect("static regex");
        let reminder_regex = Regex::new(r"^reminder\s+(.+?)\s+at\s+(.+)$").expect("static regex");
        let assignment_regex = Regex::new(r"^(\w+)\s*=\s*(.+)$").expect("static regex");
        let navigation_regex = Regex::new(r"^(?:go|navigate)\s+(\w+)$").expect("static regex");

        let mut actions = Vec::new();
        for statement in source.split(['\n', ';']) {
            let statement = statement.trim().trim_end_matches('}').trim();
            if statement.is_empty() || statement.starts_with("//") {
                continue;
            }
            if let Some(capture) = append_regex.captures(statement) {
                actions.push(Action::AppendToList {
                    variable: capture
                        .get(1)
                        .expect("variable capture")
                        .as_str()
                        .to_string(),
                    value: capture
                        .get(2)
                        .expect("value capture")
                        .as_str()
                        .trim()
                        .to_string(),
                });
            } else if let Some(capture) = remove_regex.captures(statement) {
                actions.push(Action::RemoveFromList {
                    variable: capture
                        .get(1)
                        .expect("variable capture")
                        .as_str()
                        .to_string(),
                    value: capture
                        .get(2)
                        .expect("value capture")
                        .as_str()
                        .trim()
                        .to_string(),
                });
            } else if let Some(capture) = remove_first_regex.captures(statement) {
                actions.push(Action::RemoveFirstFromList {
                    variable: capture
                        .get(1)
                        .expect("variable capture")
                        .as_str()
                        .to_string(),
                });
            } else if let Some(capture) = reminder_regex.captures(statement) {
                actions.push(Action::ScheduleReminder {
                    message: capture
                        .get(1)
                        .expect("reminder message capture")
                        .as_str()
                        .trim()
                        .to_string(),
                    time: capture
                        .get(2)
                        .expect("reminder time capture")
                        .as_str()
                        .trim()
                        .to_string(),
                });
            } else if let Some(capture) = navigation_regex.captures(statement) {
                actions.push(Action::Navigation {
                    target: capture.get(1).expect("target capture").as_str().to_string(),
                });
            } else if let Some(capture) = assignment_regex.captures(statement) {
                actions.push(Action::UpdateState {
                    variable: capture
                        .get(1)
                        .expect("variable capture")
                        .as_str()
                        .to_string(),
                    value: capture
                        .get(2)
                        .expect("value capture")
                        .as_str()
                        .trim()
                        .to_string(),
                });
            } else {
                return Err(SproutError::Parse(format!(
                    "Unsupported action statement: {statement}"
                ))
                .into());
            }
        }

        match actions.len() {
            0 => Ok(Action::Navigation {
                target: String::new(),
            }),
            1 => Ok(actions.remove(0)),
            _ => Ok(Action::Sequence { actions }),
        }
    }

    fn parse_value(&self, value: &str) -> Result<ValueType> {
        let trimmed = value.trim();
        if trimmed.contains("eval") || trimmed.contains("exec") {
            return Err(SproutError::Security("Dangerous function in value".to_string()).into());
        }
        if trimmed == "[]" {
            return Ok(ValueType::Array(Vec::new()));
        }
        if trimmed == "true" {
            return Ok(ValueType::Boolean(true));
        }
        if trimmed == "false" {
            return Ok(ValueType::Boolean(false));
        }
        if let Ok(number) = trimmed.parse::<i64>() {
            return Ok(ValueType::Number(number));
        }
        if trimmed.starts_with('"') && trimmed.ends_with('"') && trimmed.len() >= 2 {
            return Ok(ValueType::String(
                self.process_string_interpolation(&trimmed[1..trimmed.len() - 1])?,
            ));
        }
        if let Some(value) = self.variables.get(trimmed) {
            return Ok(value.clone());
        }
        Ok(ValueType::String(trimmed.to_string()))
    }

    fn process_string_interpolation(&self, text: &str) -> Result<String> {
        let interpolation = Regex::new(r#"\$\{([^}]+)\}"#).expect("static regex");
        let mut result = text.to_string();
        for capture in interpolation.captures_iter(text) {
            let full = capture.get(0).expect("interpolation capture").as_str();
            let name = capture.get(1).expect("variable capture").as_str();
            let value = self
                .variables
                .get(name)
                .ok_or_else(|| SproutError::Security(format!("Unknown variable: {name}")))?;
            let replacement = match value {
                ValueType::String(value) => value.clone(),
                ValueType::Number(value) => value.to_string(),
                ValueType::Boolean(value) => value.to_string(),
                ValueType::Array(values) => format!("{values:?}"),
                ValueType::Object(values) => format!("{values:?}"),
            };
            result = result.replace(full, &replacement);
        }
        Ok(result)
    }

    fn validate_ast(&self, app: &App) -> Result<()> {
        if app.screens.len() > App::MAX_SCREENS {
            return Err(SproutError::Security("Too many screens".to_string()).into());
        }
        app.validate().map_err(SproutError::Security)?;
        Ok(())
    }
}

fn extract_named_blocks(source: &str, keyword: &str) -> Vec<(String, String)> {
    let pattern = format!(r"(?m)\b{}\s+(\w+)\s*\{{", regex::escape(keyword));
    let regex = Regex::new(&pattern).expect("dynamic keyword regex");
    regex
        .captures_iter(source)
        .filter_map(|capture| {
            let name = capture.get(1)?.as_str().to_string();
            let opening = capture.get(0)?.end().checked_sub(1)?;
            let closing = matching_brace(source, opening)?;
            Some((name, source[opening + 1..closing].to_string()))
        })
        .collect()
}

fn extract_keyword_block(source: &str, keyword: &str) -> Option<String> {
    let pattern = format!(r"\b{}\s*\{{", regex::escape(keyword));
    let regex = Regex::new(&pattern).ok()?;
    let opening = regex.find(source)?.end().checked_sub(1)?;
    let closing = matching_brace(source, opening)?;
    Some(source[opening + 1..closing].to_string())
}

fn matching_brace(source: &str, opening: usize) -> Option<usize> {
    let bytes = source.as_bytes();
    let mut depth = 0_i32;
    let mut in_string = false;
    let mut escaped = false;
    for (offset, byte) in bytes.iter().enumerate().skip(opening) {
        match byte {
            b'\\' if in_string && !escaped => escaped = true,
            b'"' if !escaped => in_string = !in_string,
            b'{' if !in_string => depth += 1,
            b'}' if !in_string => {
                depth -= 1;
                if depth == 0 {
                    return Some(offset);
                }
            }
            _ => escaped = false,
        }
        if *byte != b'\\' {
            escaped = false;
        }
    }
    None
}

fn brace_delta(value: &str) -> i32 {
    value.chars().fold(0, |depth, character| match character {
        '{' => depth + 1,
        '}' => depth - 1,
        _ => depth,
    })
}

pub fn parse_sproutscript(source: &str) -> Result<App> {
    Parser::new(source).parse()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_interactive_todo_actions() {
        let source = r#"app "Todo" {
  start = "Todo"
}

screen Todo {
  state draft: ""
  state todos: []
  ui {
    input "New task" -> draft
    list todos
    button "Add" {
      todos.append(draft)
      draft = ""
    }
    button "Settings" -> Settings
  }
}

screen Settings {
  ui {
    label "Settings"
    button "Back" { go Back }
  }
}"#;
        let app = parse_sproutscript(source).expect("interactive source parses");
        assert_eq!(app.start_screen, "Todo");
        assert_eq!(app.screens[0].ui.len(), 4);
        assert!(matches!(
            app.screens[0].ui[2],
            UiElement::Button {
                action: Action::Sequence { .. },
                ..
            }
        ));
    }

    #[test]
    fn parses_bounded_reminder_action() {
        let source = r#"app "Reminders" { start = "Home" }
screen Home {
  state message: "Take a break"
  state time: "09:00"
  ui {
    button "Schedule" { reminder message at time }
  }
}"#;
        let app = parse_sproutscript(source).expect("reminder source parses");
        assert!(matches!(
            app.screens[0].ui[0],
            UiElement::Button {
                action: Action::ScheduleReminder { .. },
                ..
            }
        ));
    }

    #[test]
    fn rejects_dangerous_state_values() {
        let source = r#"app "Test" { start = "Home" }
screen Home { state payload: "eval('malicious')" ui { label "Safe" } }"#;
        assert!(parse_sproutscript(source).is_err());
    }
}
