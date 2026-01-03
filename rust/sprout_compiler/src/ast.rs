// Enhanced Abstract Syntax Tree for SproutScript

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct App {
    pub name: String,
    pub start_screen: String,
    pub screens: Vec<Screen>,
    pub state: Vec<StateVariable>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Screen {
    pub name: String,
    pub state: Vec<StateVariable>,
    pub ui: Vec<UiElement>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StateVariable {
    pub name: String,
    pub value: ValueType,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ValueType {
    String(String),
    Number(i64),
    Boolean(bool),
    Array(Vec<ValueType>),
    Object(HashMap<String, ValueType>),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum UiElement {
    Label {
        text: String,
    },
    Button {
        label: String,
        action: Action,
    },
    TextField {
        placeholder: String,
        bind_to: String,
    },
    Image {
        source: String,
    },
    List {
        items: Vec<String>,
        bind_to: String,
    },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum Action {
    Navigation {
        target: String,
    },
    UpdateState {
        variable: String,
        value: String,
    },
    CallFunction {
        function: String,
        args: Vec<String>,
    },
    If {
        condition: String,
        then: Box<Action>,
        else: Option<Box<Action>>,
    },
    Loop {
        variable: String,
        range: String,
        body: Vec<Action>,
    },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Function {
    pub name: String,
    pub params: Vec<String>,
    pub body: Vec<Action>,
    pub return_type: Option<ValueType>,
}

// Security: Size limits for AST elements
impl App {
    pub const MAX_NAME_LENGTH: usize = 100;
    pub const MAX_SCREENS: usize = 50;
    pub const MAX_STATE_VARS: usize = 200;
    pub const MAX_UI_ELEMENTS_PER_SCREEN: usize = 100;
}

impl Screen {
    pub const MAX_NAME_LENGTH: usize = 50;
    pub const MAX_STATE_VARS: usize = 20;
}

impl StateVariable {
    pub const MAX_NAME_LENGTH: usize = 50;
    pub const MAX_STRING_LENGTH: usize = 1000;
}

// Security: Validation methods
impl App {
    pub fn validate(&self) -> Result<(), String> {
        // Validate app name
        if self.name.len() > Self::MAX_NAME_LENGTH {
            return Err(format!("App name exceeds maximum length of {}", Self::MAX_NAME_LENGTH));
        }
        
        // Security: Check for dangerous patterns in app name
        if self.name.contains("eval") || self.name.contains("exec") {
            return Err("App name contains dangerous patterns".to_string());
        }
        
        // Validate screens
        if self.screens.len() > Self::MAX_SCREENS {
            return Err(format!("Too many screens. Maximum is {}", Self::MAX_SCREENS));
        }
        
        for screen in &self.screens {
            screen.validate()?;
        }
        
        // Validate total state variables
        let total_state = self.state.len() + self.screens.iter().map(|s| s.state.len()).sum::<usize>();
        if total_state > Self::MAX_STATE_VARS {
            return Err(format!("Too many state variables. Maximum is {}", Self::MAX_STATE_VARS));
        }
        
        Ok(())
    }
}

impl Screen {
    pub fn validate(&self) -> Result<(), String> {
        // Validate screen name
        if self.name.len() > Self::MAX_NAME_LENGTH {
            return Err(format!("Screen name exceeds maximum length of {}", Self::MAX_NAME_LENGTH));
        }
        
        // Security: Check for dangerous patterns in screen name
        if self.name.contains("eval") || self.name.contains("exec") {
            return Err("Screen name contains dangerous patterns".to_string());
        }
        
        // Validate state variables
        if self.state.len() > Self::MAX_STATE_VARS {
            return Err(format!("Too many state variables in screen '{}'. Maximum is {}", self.name, Self::MAX_STATE_VARS));
        }
        
        for state_var in &self.state {
            state_var.validate()?;
        }
        
        // Validate UI elements
        if self.ui.len() > App::MAX_UI_ELEMENTS_PER_SCREEN {
            return Err(format!("Too many UI elements in screen '{}'. Maximum is {}", self.name, App::MAX_UI_ELEMENTS_PER_SCREEN));
        }
        
        for ui_element in &self.ui {
            ui_element.validate()?;
        }
        
        Ok(())
    }
}

impl StateVariable {
    pub fn validate(&self) -> Result<(), String> {
        // Validate variable name
        if self.name.len() > Self::MAX_NAME_LENGTH {
            return Err(format!("State variable name exceeds maximum length of {}", Self::MAX_NAME_LENGTH));
        }
        
        // Security: Check for dangerous patterns
        if self.name.contains("eval") || self.name.contains("exec") {
            return Err("State variable name contains dangerous patterns".to_string());
        }
        
        // Validate value
        match &self.value {
            ValueType::String(s) => {
                if s.len() > Self::MAX_STRING_LENGTH {
                    return Err(format!("String value too long. Maximum is {}", Self::MAX_STRING_LENGTH));
                }
                
                // Security: Check for dangerous patterns in strings
                if s.contains("eval(") || s.contains("exec(") {
                    return Err("String value contains dangerous function calls".to_string());
                }
            }
            ValueType::Array(arr) => {
                if arr.len() > 100 {
                    return Err("Array too large. Maximum is 100 elements".to_string());
                }
            }
            ValueType::Object(obj) => {
                if obj.len() > 50 {
                    return Err("Object too large. Maximum is 50 properties".to_string());
                }
            }
            _ => {}
        }
        
        Ok(())
    }
}

impl UiElement {
    pub fn validate(&self) -> Result<(), String> {
        match self {
            UiElement::Label { text } => {
                if text.len() > 1000 {
                    return Err("Label text too long. Maximum is 1000 characters".to_string());
                }
                
                // Security: Check for XSS patterns
                if text.contains("<script>") || text.contains("javascript:") {
                    return Err("Label text contains dangerous patterns".to_string());
                }
            }
            UiElement::Button { label, action } => {
                if label.len() > 50 {
                    return Err("Button label too long. Maximum is 50 characters".to_string());
                }
                action.validate()?;
            }
            UiElement::TextField { placeholder, bind_to } => {
                if placeholder.len() > 200 {
                    return Err("Placeholder too long".to_string());
                }
                if bind_to.len() > 50 {
                    return Err("Binding variable name too long".to_string());
                }
            }
            UiElement::Image { source } => {
                if source.len() > 500 {
                    return Err("Image source URL too long".to_string());
                }
                
                // Security: Validate URL protocol
                if source.starts_with("http://") && !source.starts_with("http://localhost") {
                    return Err("Insecure HTTP connection not allowed".to_string());
                }
            }
            UiElement::List { items, bind_to } => {
                if items.len() > 100 {
                    return Err("List too large. Maximum is 100 items".to_string());
                }
                if bind_to.len() > 50 {
                    return Err("Binding variable name too long".to_string());
                }
            }
        }
        
        Ok(())
    }
}

impl Action {
    pub fn validate(&self) -> Result<(), String> {
        match self {
            Action::Navigation { target } => {
                if target.len() > 50 {
                    return Err("Navigation target too long".to_string());
                }
            }
            Action::UpdateState { variable, value } => {
                if variable.len() > 50 {
                    return Err("State variable name too long".to_string());
                }
                if value.len() > 500 {
                    return Err("State value too long".to_string());
                }
            }
            Action::CallFunction { function, args } => {
                // Security: Check for dangerous function calls
                if function.contains("eval") || function.contains("exec") {
                    return Err("Dangerous function call detected".to_string());
                }
                
                if function.len() > 50 {
                    return Err("Function name too long".to_string());
                }
                
                if args.len() > 10 {
                    return Err("Too many arguments. Maximum is 10".to_string());
                }
                
                for arg in args {
                    if arg.len() > 200 {
                        return Err("Argument too long".to_string());
                    }
                }
            }
            Action::If { condition, then, else: else_action } => {
                if condition.len() > 200 {
                    return Err("Condition too long".to_string());
                }
                
                // Security: Check for dangerous patterns in conditions
                if condition.contains("eval") || condition.contains("exec") {
                    return Err("Condition contains dangerous patterns".to_string());
                }
                
                then.validate()?;
                if let Some(else_act) = else_action {
                    else_act.validate()?;
                }
            }
            Action::Loop { variable, range, body } => {
                if variable.len() > 50 {
                    return Err("Loop variable name too long".to_string());
                }
                if range.len() > 100 {
                    return Err("Loop range too long".to_string());
                }
                
                // Security: Limit loop iterations
                if body.len() > 100 {
                    return Err("Loop body too large. Maximum is 100 actions".to_string());
                }
                
                for action in body {
                    action.validate()?;
                }
            }
        }
        
        Ok(())
    }
}