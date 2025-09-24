// rust/sprout_compiler/src/enhanced_parser.rs
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
    #[error("Expected '{'")]
    ExpectedOpenBrace,
    #[error("Expected '}'")]
    ExpectedCloseBrace,
    #[error("Expected '='")]
    ExpectedEquals,
    #[error("Invalid number")]
    InvalidNumber,
    #[error("Missing required field: {0}")]
    MissingField(String),
    #[error("Invalid syntax at line {0}: {1}")]
    InvalidSyntax(usize, String),
    #[error("Undefined reference: {0}")]
    UndefinedReference(String),
    #[error("Type mismatch: expected {0}, got {1}")]
    TypeMismatch(String, String),
    #[error("Duplicate definition: {0}")]
    DuplicateDefinition(String),
}

/// Enhanced parser with better error handling and validation
pub fn parse(source: &str) -> Result<App, ParseError> {
    // Track line numbers for better error reporting
    let lines: Vec<&str> = source.lines().collect();
    let line_map = create_line_map(source);
    
    let tokens = tokenize(source);
    let mut iter = tokens.iter().peekable();

    let mut app = parse_app(&mut iter)?;
    app.imports = parse_imports(&mut iter)?;
    app.data_models = parse_data_models(&mut iter)?;
    app.screens = parse_screens(&mut iter)?;

    // Validate the parsed app
    validate_app(&app, &lines)?;

    Ok(app)
}

/// Create a mapping of token positions to line numbers
fn create_line_map(source: &str) -> Vec<usize> {
    let mut line_map = Vec::new();
    let mut line_number = 1;
    
    for (i, c) in source.chars().enumerate() {
        line_map.push(line_number);
        if c == '\n' {
            line_number += 1;
        }
    }
    
    line_map
}

/// Validate the parsed app for semantic errors
fn validate_app(app: &App, lines: &[&str]) -> Result<(), ParseError> {
    // Check if start screen exists
    let start_screen = &app.start_screen;
    if !app.screens.iter().any(|s| s.name == *start_screen) {
        return Err(ParseError::UndefinedReference(format!("Start screen '{}' not defined", start_screen)));
    }
    
    // Validate screens
    for screen in &app.screens {
        validate_screen(screen, app, lines)?;
    }
    
    Ok(())
}

/// Validate a screen for semantic errors
fn validate_screen(screen: &Screen, app: &App, lines: &[&str]) -> Result<(), ParseError> {
    // Check for duplicate state declarations
    let mut state_names = std::collections::HashSet::new();
    for state in &screen.state {
        if !state_names.insert(&state.name) {
            return Err(ParseError::DuplicateDefinition(format!("State '{}' defined multiple times", state.name)));
        }
    }
    
    // Validate UI elements
    validate_ui(&screen.ui, screen, app, lines)?;
    
    Ok(())
}

/// Validate UI elements
fn validate_ui(ui: &UI, screen: &Screen, app: &App, lines: &[&str]) -> Result<(), ParseError> {
    match ui {
        UI::Button { navigate: Some(nav), .. } => {
            // Check if target screen exists
            if !app.screens.iter().any(|s| s.name == nav.screen) && nav.screen != "Back" {
                return Err(ParseError::UndefinedReference(format!("Target screen '{}' not defined", nav.screen)));
            }
        },
        UI::List { items, .. } => {
            // Check if list items variable exists
            if !screen.state.iter().any(|s| s.name == *items) {
                return Err(ParseError::UndefinedReference(format!("List items '{}' not defined", items)));
            }
        },
        UI::Binding { variable, .. } => {
            // Check if bound variable exists
            if !screen.state.iter().any(|s| s.name == *variable) {
                return Err(ParseError::UndefinedReference(format!("Bound variable '{}' not defined", variable)));
            }
        },
        UI::Column(items) | UI::Row(items) | UI::Stack(items) => {
            // Recursively validate child UI elements
            for item in items {
                validate_ui(item, screen, app, lines)?;
            }
        },
        UI::Conditional { condition, then_branch, else_branch } => {
            // Validate condition expression
            // (In a real implementation, we would check expression validity)
            
            // Validate branches
            validate_ui(then_branch, screen, app, lines)?;
            if let Some(else_branch) = else_branch {
                validate_ui(else_branch, screen, app, lines)?;
            }
        },
        _ => {}
    }
    
    Ok(())
}

// Re-export the tokenize function from the original parser
pub fn tokenize(source: &str) -> Vec<String> {
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

// Helper functions from the original parser
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

// Import the original parser functions to use them in this enhanced version
use crate::parser::{
    parse_app, parse_imports, parse_data_models, parse_screens
};