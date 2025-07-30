// rust/sprout_compiler/src/parser.rs
use crate::ast::*;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum ParseError {
    #[error("Unexpected token: {0}")]
    Unexpected(String),
    #[error("Expected identifier")]
    ExpectedIdent,
    #[error("Unterminated string")]
    UnterminatedString,
    #[error("Expected '{{'")]
    ExpectedOpenBrace,
    #[error("Expected '}}'")]
    ExpectedCloseBrace,
    #[error("Expected '='")]
    ExpectedEquals,
    #[error("Invalid number")]
    InvalidNumber,
}

pub fn parse(source: &str) -> Result<App, ParseError> {
    let tokens = tokenize(source);
    let mut iter = tokens.iter().peekable();

    let mut app = parse_app(&mut iter)?;
    app.imports = parse_imports(&mut iter)?;
    app.data_models = parse_data_models(&mut iter)?;
    app.screens = parse_screens(&mut iter)?;

    Ok(app)
}

fn parse_app(iter: &mut std::iter::Peekable<std::vec::IntoIter<String>>) -> Result<App, ParseError> {
    expect(iter, "app")?;
    let name = parse_string(iter)?;
    expect(iter, "{")?;
    expect(iter, "start")?;
    expect(iter, "=")?;
    let start_screen = expect_ident(iter)?;
    expect(iter, "}")?;
    Ok(App::new(&name, &start_screen))
}

fn parse_imports(iter: &mut std::iter::Peekable<std::vec::IntoIter<String>>) -> Result<Vec<Import>, ParseError> {
    let mut imports = Vec::new();
    while iter.peek() == Some(&"import".to_string()) {
        imports.push(parse_import(iter)?);
    }
    Ok(imports)
}

fn parse_import(iter: &mut std::iter::Peekable<std::vec::IntoIter<String>>) -> Result<Import, ParseError> {
    expect(iter, "import")?;
    let name = parse_string(iter)?;
    expect(iter, "from")?;
    let path = parse_string(iter)?;
    Ok(Import { name, path })
}

fn parse_data_models(iter: &mut std::iter::Peekable<std::vec::IntoIter<String>>) -> Result<Vec<DataModel>, ParseError> {
    let mut models = Vec::new();
    while iter.peek() == Some(&"data".to_string()) {
        models.push(parse_data_model(iter)?);
    }
    Ok(models)
}

fn parse_data_model(iter: &mut std::iter::Peekable<std::vec::IntoIter<String>>) -> Result<DataModel, ParseError> {
    expect(iter, "data")?;
    let name = expect_ident(iter)?;
    expect(iter, "{")?;

    let mut fields = Vec::new();
    while iter.peek().map(|t| t != "}") == Some(true) {
        fields.push(parse_data_field(iter)?);
    }

    expect(iter, "}")?;
    let mut model = DataModel::new(&name);
    model.fields = fields;
    Ok(model)
}

fn parse_data_field(iter: &mut std::iter::Peekable<std::vec::IntoIter<String>>) -> Result<DataField, ParseError> {
    let name = expect_ident(iter)?;
    expect(iter, ":")?;
    let type_name = match expect_ident(iter)?.as_str() {
        "String" => DataType::String,
        "Int" => DataType::Int,
        "Float" => DataType::Float,
        "Boolean" => DataType::Boolean,
        "Date" => DataType::Date,
        other => DataType::Custom(other.to_string()),
    };
    let default = if iter.peek() == Some(&"=".to_string()) {
        iter.next();
        Some(parse_expr(iter)?)
    } else {
        None
    };
    Ok(DataField { name, type_name, default })
}

fn parse_screens(iter: &mut std::iter::Peekable<std::vec::IntoIter<String>>) -> Result<Vec<Screen>, ParseError> {
    let mut screens = Vec::new();
    while let Some(token) = iter.peek() {
        if *token == "screen" {
            screens.push(parse_screen(iter)?);
        } else {
            iter.next();
        }
    }
    Ok(screens)
}

fn parse_screen(iter: &mut std::iter::Peekable<std::vec::IntoIter<String>>) -> Result<Screen, ParseError> {
    expect(iter, "screen")?;
    let name = expect_ident(iter)?;
    let parameters = if iter.peek() == Some(&"(") {
        parse_parameters(iter)?
    } else {
        vec![]
    };
    expect(iter, "{")?;

    let mut state = Vec::new();
    while iter.peek() == Some(&"state".to_string()) {
        state.push(parse_state(iter)?);
    }

    expect(iter, "ui")?;
    expect(iter, "{")?;
    let ui = parse_ui(iter)?;
    expect(iter, "}")?;

    let mut actions = Vec::new();
    while iter.peek().map(|t| t != "}") == Some(true) {
        if let Some(action) = parse_action(iter)? {
            actions.push(action);
        }
    }

    expect(iter, "}")?;

    let mut screen = Screen::new(&name);
    screen.parameters = parameters;
    screen.state = state;
    screen.ui = ui;
    screen.actions = actions;

    Ok(screen)
}

fn parse_parameters(iter: &mut std::iter::Peekable<std::vec::IntoIter<String>>) -> Result<Vec<Parameter>, ParseError> {
    expect(iter, "(")?;
    let mut params = Vec::new();
    while iter.peek() != Some(&")".to_string()) {
        let name = expect_ident(iter)?;
        expect(iter, ":")?;
        let type_name = expect_ident(iter)?;
        params.push(Parameter { name, type_name });
        if iter.peek() == Some(&",".to_string()) {
            iter.next();
        }
    }
    expect(iter, ")")?;
    Ok(params)
}

fn parse_state(iter: &mut std::iter::Peekable<std::vec::IntoIter<String>>) -> Result<StateDecl, ParseError> {
    expect(iter, "state")?;
    let name = expect_ident(iter)?;
    expect(iter, "=")?;
    let value = parse_expr(iter)?;
    Ok(StateDecl::new(&name, value))
}

fn parse_ui(iter: &mut std::iter::Peekable<std::vec::IntoIter<String>>) -> Result<UI, ParseError> {
    let token = iter.next().ok_or(ParseError::Unexpected("EOF".to_string()))?;

    match token.as_str() {
        "column" => parse_container(iter, UI::Column),
        "row" => parse_container(iter, UI::Row),
        "stack" => parse_container(iter, UI::Stack),
        "label" => {
            let content = parse_string_or_expr(iter)?;
            Ok(UI::Label(content))
        }
        "title" => {
            let content = parse_string_or_expr(iter)?;
            Ok(UI::Title(content))
        }
        "button" => {
            let label = parse_string_or_expr(iter)?;
            let (action, navigate) = parse_action_block(iter)?;
            Ok(UI::Button { label, action, navigate })
        }
        "image" => {
            let src = parse_string(iter)?;
            Ok(UI::Image { src })
        }
        "input" => {
            let label = parse_string(iter)?;
            expect(iter, "binding")?;
            expect(iter, ":")?;
            let binding = expect_ident(iter)?;
            Ok(UI::Input { label, binding })
        }
        "list" => {
            let items = expect_ident(iter)?;
            expect(iter, "{")?;
            let child = Box::new(parse_ui(iter)?);
            expect(iter, "}")?;
            Ok(UI::List { items, child })
        }
        "if" => {
            let condition = parse_expr(iter)?;
            expect(iter, "{")?;
            let then_branch = Box::new(parse_ui(iter)?);
            expect(iter, "}")?;
            let else_branch = if iter.peek() == Some(&"else".to_string()) {
                iter.next();
                expect(iter, "{")?;
                let ui = parse_ui(iter)?;
                expect(iter, "}")?;
                Some(Box::new(ui))
            } else {
                None
            };
            Ok(UI::Conditional { condition, then_branch, else_branch })
        }
        _ if token.starts_with('$') && token.contains('{') => {
            // Interpolated label
            let expr = parse_interpolated_string(&token)?;
            Ok(UI::Label(expr))
        }
        _ => Err(ParseError::Unexpected(token)),
    }
}

fn parse_container<F>(iter: &mut std::iter::Peekable<std::vec::IntoIter<String>>, constructor: F) -> Result<UI, ParseError>
where
    F: Fn(Vec<UI>) -> UI,
{
    expect(iter, "{")?;
    let mut children = Vec::new();
    while iter.peek().map(|t| t != "}") == Some(true) {
        children.push(parse_ui(iter)?);
    }
    expect(iter, "}")?;
    Ok(constructor(children))
}

fn parse_string_or_expr(iter: &mut std::iter::Peekable<std::vec::IntoIter<String>>) -> Result<String, ParseError> {
    if let Some(token) = iter.peek() {
        if token.starts_with('"') && token.ends_with('"') {
            return parse_string(iter);
        }
    }
    // Assume it's an expression like "${count}"
    let token = iter.next().unwrap();
    if token.starts_with('$') && token.contains('{') {
        Ok(token)
    } else {
        Err(ParseError::Unexpected(token))
    }
}

fn parse_action_block(iter: &mut std::iter::Peekable<std::vec::IntoIter<String>>) -> Result<(Option<String>, Option<Navigation>), ParseError> {
    expect(iter, "{")?;
    let mut action_code = String::new();
    let mut navigate: Option<Navigation> = None;

    while iter.peek().map(|t| t != "}") == Some(true) {
        let token = iter.next().unwrap();
        if token == "->" {
            let screen = expect_ident(iter)?;
            if iter.peek() == Some(&"(") {
                let args = parse_arg_list(iter)?;
                navigate = Some(Navigation { screen, args });
            } else {
                navigate = Some(Navigation { screen, args: vec![] });
            }
        } else {
            action_code.push_str(&token);
            action_code.push(' ');
        }
    }
    expect(iter, "}")?;

    let action = if action_code.trim().is_empty() {
        None
    } else {
        Some(action_code.trim().to_string())
    };

    Ok((action, navigate))
}

fn parse_arg_list(iter: &mut std::iter::Peekable<std::vec::IntoIter<String>>) -> Result<Vec<Expr>, ParseError> {
    expect(iter, "(")?;
    let mut args = Vec::new();
    while iter.peek() != Some(&")".to_string()) {
        args.push(parse_expr(iter)?);
        if iter.peek() == Some(&",".to_string()) {
            iter.next();
        }
    }
    expect(iter, ")")?;
    Ok(args)
}

fn parse_action(iter: &mut std::iter::Peekable<std::vec::IntoIter<String>>) -> Result<Option<Action>, ParseError> {
    if iter.peek().map(|t| t == "on") == Some(true) {
        iter.next();
        let event = expect_ident(iter)?;
        expect(iter, "{")?;
        let mut code = String::new();
        while iter.peek().map(|t| t != "}") == Some(true) {
            code.push_str(&iter.next().unwrap());
            code.push(' ');
        }
        expect(iter, "}")?;
        return Ok(Some(Action { code: code.trim().to_string() }));
    }
    Ok(None)
}

fn parse_expr(iter: &mut std::iter::Peekable<std::vec::IntoIter<String>>) -> Result<Expr, ParseError> {
    // MVP: parse simple expressions: 1, "hello", count, count + 1
    let token = iter.next().ok_or(ParseError::Unexpected("EOF".to_string()))?;

    if let Ok(num) = token.parse::<f64>() {
        return Ok(Expr::Number(num));
    }

    if token.starts_with('"') && token.ends_with('"') {
        return Ok(Expr::String(token[1..token.len() - 1].to_string()));
    }

    if token == "true" {
        return Ok(Expr::Boolean(true));
    }

    if token == "false" {
        return Ok(Expr::Boolean(false));
    }

    // Variable or function call
    if iter.peek() == Some(&"(") {
        // Function call
        iter.next(); // consume '('
        let mut args = Vec::new();
        while iter.peek() != Some(&")".to_string()) {
            args.push(parse_expr(iter)?);
            if iter.peek() == Some(&",".to_string()) {
                iter.next();
            }
        }
        expect(iter, ")");
        return Ok(Expr::FunctionCall { name: token, args });
    }

    Ok(Expr::Variable(token))
}

fn parse_interpolated_string(s: &str) -> Result<String, ParseError> {
    // Already stored as "${count}" — no need to parse further here
    Ok(s.to_string())
}

// Tokenizer
fn tokenize(source: &str) -> Vec<String> {
    source
        .replace("{", " { ")
        .replace("}", " } ")
        .replace("(", " ( ")
        .replace(")", " ) ")
        .replace("->", " -> ")
        .replace("=", " = ")
        .replace(":", " : ")
        .replace(",", " , ")
        .split_whitespace()
        .map(|s| s.to_string())
        .collect()
}

// Helpers
fn expect<T>(iter: &mut T, expected: &str) -> Result<(), ParseError>
where
    T: Iterator<Item = String>,
{
    if iter.next().as_deref() == Some(expected) {
        Ok(())
    } else {
        Err(ParseError::Unexpected(expected.to_string()))
    }
}

fn expect_ident<T>(iter: &mut T) -> Result<String, ParseError>
where
    T: Iterator<Item = String>,
{
    iter.next().ok_or(ParseError::ExpectedIdent)
}

fn parse_string<T>(iter: &mut T) -> Result<String, ParseError>
where
    T: Iterator<Item = String>,
{
    let s = iter.next().ok_or(ParseError::UnterminatedString)?;
    if s.starts_with('"') && s.ends_with('"') {
        Ok(s[1..s.len() - 1].to_string())
    } else {
        Err(ParseError::UnterminatedString)
    }
}