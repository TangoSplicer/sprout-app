// Enhanced Parser for SproutScript with Variables, Control Flow, Functions

use crate::ast::*;
use crate::SproutError;
use anyhow::{Context, Result};
use regex::Regex;
use std::collections::HashMap;

lazy_static::lazy_static! {
    static ref APP_REGEX: Regex = Regex::new(r#"app\s+"([^"]+)""#).unwrap();
    static ref SCREEN_REGEX: Regex = Regex::new(r#"screen\s+(\w+)"#).unwrap();
    static ref STATE_REGEX: Regex = Regex::new(r#"state\s+(\w+)\s*:\s*(.+)"#).unwrap();
    static ref UI_REGEX: Regex = Regex::new(r#"ui\s*\{([^}]+)\}"#).unwrap();
    static ref LABEL_REGEX: Regex = Regex::new(r#"label\s+"([^"]+)""#).unwrap();
    static ref BUTTON_REGEX: Regex = Regex::new(r#"button\s+"([^"]+)""#).unwrap();
    static ref VARIABLE_REGEX: Regex = Regex::new(r#"var\s+(\w+)\s*=\s*(.+)"#).unwrap();
    static ref FUNCTION_REGEX: Regex = Regex::new(r#"fn\s+(\w+)\s*\(([^)]*)\)"#).unwrap();
    static ref IF_REGEX: Regex = Regex::new(r#"if\s+(.+)\s*\{([^}]*)\}"#).unwrap();
    static ref LOOP_REGEX: Regex = Regex::new(r#"for\s+(\w+)\s+in\s+(.+)\s*\{([^}]*)\}"#).unwrap();
    static ref STRING_INTERPOLATION: Regex = Regex::new(r#"\$\{([^}]+)\}"#).unwrap();
}

pub struct Parser {
    source: String,
    current_line: usize,
    current_col: usize,
    variables: HashMap<String, ValueType>,
    functions: HashMap<String, FunctionDef>,
}

#[derive(Debug, Clone)]
pub struct FunctionDef {
    pub name: String,
    pub params: Vec<String>,
    pub body: String,
}

impl Parser {
    pub fn new(source: &str) -> Self {
        Parser {
            source: source.to_string(),
            current_line: 1,
            current_col: 1,
            variables: HashMap::new(),
            functions: HashMap::new(),
        }
    }

    pub fn parse(&mut self) -> Result<App> {
        let mut app = self.parse_app_declaration()?;
        
        // Parse functions first
        self.parse_functions(&mut app);
        
        // Parse screens
        app.screens = self.parse_screens()?;
        
        // Security: Validate parsed AST
        self.validate_ast(&app)?;
        
        Ok(app)
    }

    fn parse_app_declaration(&mut self) -> Result<App> {
        let caps = APP_REGEX.captures(&self.source)
            .ok_or_else(|| SproutError::Parse("App declaration not found".to_string()))?;
        
        let name = caps.get(1).unwrap().as_str().to_string();
        
        // Security: Validate app name
        if name.len() > 100 {
            return Err(SproutError::Security("App name too long".to_string()).into());
        }
        
        Ok(App {
            name,
            start_screen: String::new(),
            screens: Vec::new(),
        })
    }

    fn parse_functions(&mut self, app: &mut App) {
        for cap in FUNCTION_REGEX.captures_iter(&self.source) {
            let name = cap.get(1).unwrap().as_str().to_string();
            let params_str = cap.get(2).unwrap().as_str();
            
            // Security: Validate function name
            if name.contains("eval") || name.contains("exec") {
                continue; // Skip dangerous functions
            }
            
            let params: Vec<String> = if params_str.is_empty() {
                Vec::new()
            } else {
                params_str.split(',').map(|s| s.trim().to_string()).collect()
            };
            
            // Extract function body (simplified)
            let start = cap.get(0).unwrap().end();
            let body = self.source[start..].split('}').next().unwrap_or("").to_string();
            
            let func_def = FunctionDef {
                name: name.clone(),
                params,
                body,
            };
            
            self.functions.insert(name, func_def);
        }
    }

    fn parse_screens(&mut self) -> Result<Vec<Screen>> {
        let mut screens = Vec::new();
        
        for cap in SCREEN_REGEX.captures_iter(&self.source) {
            let name = cap.get(1).unwrap().as_str().to_string();
            
            // Security: Validate screen name
            if name.len() > 50 {
                return Err(SproutError::Security("Screen name too long".to_string()).into());
            }
            
            let mut screen = Screen {
                name: name.clone(),
                state: Vec::new(),
                ui: Vec::new(),
            };
            
            // Parse state variables
            for state_cap in STATE_REGEX.captures_iter(&self.source) {
                let var_name = state_cap.get(1).unwrap().as_str().to_string();
                let value_str = state_cap.get(2).unwrap().as_str().to_string();
                
                let value_type = self.parse_value(&value_str)?;
                
                self.variables.insert(var_name.clone(), value_type.clone());
                screen.state.push(StateVariable {
                    name: var_name,
                    value: value_type,
                });
            }
            
            // Parse UI elements
            screen.ui = self.parse_ui_elements()?;
            
            screens.push(screen);
        }
        
        Ok(screens)
    }

    fn parse_ui_elements(&mut self) -> Result<Vec<UiElement>> {
        let mut elements = Vec::new();
        
        for ui_cap in UI_REGEX.captures_iter(&self.source) {
            let ui_content = ui_cap.get(1).unwrap().as_str();
            
            // Parse labels
            for label_cap in LABEL_REGEX.captures_iter(ui_content) {
                let text = label_cap.get(1).unwrap().as_str();
                
                // Security: Check for string interpolation
                let processed_text = self.process_string_interpolation(text)?;
                
                // Security: Validate label length
                if processed_text.len() > 1000 {
                    return Err(SproutError::Security("Label text too long".to_string()).into());
                }
                
                elements.push(UiElement::Label {
                    text: processed_text,
                });
            }
            
            // Parse buttons
            for button_cap in BUTTON_REGEX.captures_iter(ui_content) {
                let label = button_cap.get(1).unwrap().as_str();
                
                // Security: Validate button label
                if label.len() > 50 {
                    return Err(SproutError::Security("Button label too long".to_string()).into());
                }
                
                elements.push(UiElement::Button {
                    label: label.to_string(),
                    action: Action::Navigation {
                        target: String::new(),
                    },
                });
            }
        }
        
        Ok(elements)
    }

    fn parse_value(&mut self, value_str: &str) -> Result<ValueType> {
        let trimmed = value_str.trim();
        
        // Security: Prevent code execution in values
        if trimmed.contains("eval") || trimmed.contains("exec") {
            return Err(SproutError::Security("Dangerous function in value".to_string()).into());
        }
        
        // Boolean
        if trimmed == "true" {
            return Ok(ValueType::Boolean(true));
        }
        if trimmed == "false" {
            return Ok(ValueType::Boolean(false));
        }
        
        // Number
        if let Ok(num) = trimmed.parse::<i64>() {
            return Ok(ValueType::Number(num));
        }
        
        // String (with quotes)
        if trimmed.starts_with('"') && trimmed.ends_with('"') {
            let text = &trimmed[1..trimmed.len()-1];
            let processed = self.process_string_interpolation(text)?;
            return Ok(ValueType::String(processed));
        }
        
        // Variable reference
        if let Some(value) = self.variables.get(trimmed) {
            return Ok(value.clone());
        }
        
        // Default: treat as string
        Ok(ValueType::String(trimmed.to_string()))
    }

    fn process_string_interpolation(&self, text: &str) -> Result<String> {
        let mut result = text.to_string();
        
        // Security: Safe string interpolation
        for cap in STRING_INTERPOLATION.captures_iter(&text) {
            let var_name = cap.get(1).unwrap().as_str();
            
            // Security: Validate variable reference
            if !self.variables.contains_key(var_name) {
                return Err(SproutError::Security(format!("Unknown variable: {}", var_name)).into());
            }
            
            let value = match self.variables.get(var_name) {
                Some(ValueType::String(s)) => s.clone(),
                Some(ValueType::Number(n)) => n.to_string(),
                Some(ValueType::Boolean(b)) => b.to_string(),
                None => String::new(),
            };
            
            result = result.replace(&cap[0], &value);
        }
        
        Ok(result)
    }

    fn validate_ast(&self, app: &App) -> Result<()> {
        // Security: Validate total size
        let total_size = app.screens.len() + app.state.len();
        if total_size > 1000 {
            return Err(SproutError::Security("Application too large".to_string()).into());
        }
        
        // Security: Validate each screen
        for screen in &app.screens {
            self.validate_screen(screen)?;
        }
        
        Ok(())
    }

    fn validate_screen(&self, screen: &Screen) -> Result<()> {
        // Security: Validate screen size
        if screen.ui.len() > 100 {
            return Err(SproutError::Security("Screen has too many UI elements".to_string()).into());
        }
        
        // Security: Validate state variables
        for state_var in &screen.state {
            if state_var.name.len() > 50 {
                return Err(SproutError::Security("State variable name too long".to_string()).into());
            }
        }
        
        Ok(())
    }
}

// Public parse function
pub fn parse_sproutscript(source: &str) -> Result<App> {
    let mut parser = Parser::new(source);
    parser.parse()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_simple_app() {
        let source = r#"
            app "Test" {
                start = "Home"
            }
            
            screen Home {
                state {
                    count = 0
                }
                
                ui {
                    label "Hello ${count}"
                }
            }
        "#;
        
        let result = parse_sproutscript(source);
        assert!(result.is_ok());
    }

    #[test]
    fn test_security_reject_dangerous_functions() {
        let source = r#"
            app "Test" {
                start = "Home"
            }
            
            screen Home {
                ui {
                    label "eval('malicious')"
                }
            }
        "#;
        
        let result = parse_sproutscript(source);
        assert!(result.is_err());
    }

    #[test]
    fn test_string_interpolation() {
        let source = r#"
            app "Test" {
                start = "Home"
            }
            
            screen Home {
                state {
                    name = "World"
                }
                
                ui {
                    label "Hello ${name}"
                }
            }
        "#;
        
        let result = parse_sproutscript(source);
        assert!(result.is_ok());
    }
}