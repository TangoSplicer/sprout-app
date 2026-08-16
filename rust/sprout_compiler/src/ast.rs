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

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
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
    /// A multi-line text surface for journals, notes, reflections, and plans.
    TextArea {
        placeholder: String,
        bind_to: String,
    },
    /// A bounded decimal input for amounts, quantities, and rates.
    NumberField {
        placeholder: String,
        bind_to: String,
    },
    /// A bounded single-choice control with source-defined options.
    Choice {
        label: String,
        options: Vec<String>,
        bind_to: String,
    },
    /// A bounded visual progress indicator based on numeric state values.
    Progress {
        label: String,
        value: String,
        total: String,
    },
    /// A structured local collection rendered with author-selected fields.
    RecordList {
        bind_to: String,
        fields: Vec<String>,
        search_binding: Option<String>,
        filter_binding: Option<String>,
        editable: bool,
    },
    /// A calculated category breakdown for selected record kinds.
    Breakdown {
        label: String,
        collection: String,
        amount_field: String,
        kinds: Vec<String>,
    },
    /// A computed local total grouped by the bounded `kind` field of records.
    Aggregate {
        label: String,
        collection: String,
        amount_field: String,
        positive_kinds: Vec<String>,
        negative_kinds: Vec<String>,
    },
    Image {
        source: String,
    },
    List {
        items: Vec<String>,
        bind_to: String,
    },
    /// A concise visual grouping with an optional supporting detail.
    Section {
        title: String,
        detail: Option<String>,
    },
    /// A prominent read-only value bound to state, useful for progress and totals.
    Metric {
        label: String,
        bind_to: String,
    },
    /// A bounded boolean control that writes only to its declared state binding.
    Toggle {
        label: String,
        bind_to: String,
    },
    /// A visual separator for longer task-focused screens.
    Divider,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RecordField {
    pub name: String,
    pub value: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum Action {
    /// Executes a bounded list of actions in source order.
    Sequence {
        actions: Vec<Action>,
    },
    /// Navigates to a declared screen. `Back` returns to the prior screen.
    Navigation {
        target: String,
    },
    /// Replaces a scalar state value with a safe literal or state reference.
    UpdateState {
        variable: String,
        value: String,
    },
    /// Appends a resolved value to a list state variable.
    AppendToList {
        variable: String,
        value: String,
    },
    /// Removes the first matching resolved value from a list state variable.
    RemoveFromList {
        variable: String,
        value: String,
    },
    /// Removes the first item from a list state variable.
    RemoveFirstFromList {
        variable: String,
    },
    /// Requests a local reminder with a bounded message and a time expression.
    ScheduleReminder {
        message: String,
        time: String,
    },
    /// Adjusts a numeric state value by a bounded signed amount.
    Increment {
        variable: String,
        by: i64,
    },
    /// Empties a declared list state variable without accessing external data.
    ClearList {
        variable: String,
    },
    /// Appends a bounded object made from explicit field-to-expression pairs.
    AppendRecord {
        variable: String,
        fields: Vec<RecordField>,
    },
    /// Triggers secure local-network data sync for collaborative shared apps.
    SyncData {
        collection: String,
    },
    /// Dispatches an instant contextual notification to the user.
    NotifyUser {
        message: String,
    },
    CallFunction {
        function: String,
        args: Vec<String>,
    },
    If {
        condition: String,
        then: Box<Action>,
        r#else: Option<Box<Action>>,
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
            return Err(format!(
                "App name exceeds maximum length of {}",
                Self::MAX_NAME_LENGTH
            ));
        }

        // Security: Check for dangerous patterns in app name
        if self.name.contains("eval") || self.name.contains("exec") {
            return Err("App name contains dangerous patterns".to_string());
        }

        // Validate screens
        if self.screens.len() > Self::MAX_SCREENS {
            return Err(format!(
                "Too many screens. Maximum is {}",
                Self::MAX_SCREENS
            ));
        }

        for screen in &self.screens {
            screen.validate()?;
        }

        // Validate total state variables
        let total_state =
            self.state.len() + self.screens.iter().map(|s| s.state.len()).sum::<usize>();
        if total_state > Self::MAX_STATE_VARS {
            return Err(format!(
                "Too many state variables. Maximum is {}",
                Self::MAX_STATE_VARS
            ));
        }

        Ok(())
    }
}

impl Screen {
    pub fn validate(&self) -> Result<(), String> {
        // Validate screen name
        if self.name.len() > Self::MAX_NAME_LENGTH {
            return Err(format!(
                "Screen name exceeds maximum length of {}",
                Self::MAX_NAME_LENGTH
            ));
        }

        // Security: Check for dangerous patterns in screen name
        if self.name.contains("eval") || self.name.contains("exec") {
            return Err("Screen name contains dangerous patterns".to_string());
        }

        // Validate state variables
        if self.state.len() > Self::MAX_STATE_VARS {
            return Err(format!(
                "Too many state variables in screen '{}'. Maximum is {}",
                self.name,
                Self::MAX_STATE_VARS
            ));
        }

        for state_var in &self.state {
            state_var.validate()?;
        }

        // Validate UI elements
        if self.ui.len() > App::MAX_UI_ELEMENTS_PER_SCREEN {
            return Err(format!(
                "Too many UI elements in screen '{}'. Maximum is {}",
                self.name,
                App::MAX_UI_ELEMENTS_PER_SCREEN
            ));
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
            return Err(format!(
                "State variable name exceeds maximum length of {}",
                Self::MAX_NAME_LENGTH
            ));
        }

        // Security: Check for dangerous patterns
        if self.name.contains("eval") || self.name.contains("exec") {
            return Err("State variable name contains dangerous patterns".to_string());
        }

        // Validate value
        match &self.value {
            ValueType::String(s) => {
                if s.len() > Self::MAX_STRING_LENGTH {
                    return Err(format!(
                        "String value too long. Maximum is {}",
                        Self::MAX_STRING_LENGTH
                    ));
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
            ValueType::Object(obj) if obj.len() > 50 => {
                return Err("Object too large. Maximum is 50 properties".to_string());
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
            UiElement::TextField {
                placeholder,
                bind_to,
            }
            | UiElement::TextArea {
                placeholder,
                bind_to,
            }
            | UiElement::NumberField {
                placeholder,
                bind_to,
            } => {
                if placeholder.len() > 200 {
                    return Err("Placeholder too long".to_string());
                }
                if bind_to.len() > 50 {
                    return Err("Binding variable name too long".to_string());
                }
            }
            UiElement::Choice {
                label,
                options,
                bind_to,
            } => {
                if label.is_empty() || label.len() > 120 || bind_to.len() > 50 {
                    return Err("Choice declaration is invalid".to_string());
                }
                if options.is_empty()
                    || options.len() > 8
                    || options
                        .iter()
                        .any(|value| value.is_empty() || value.len() > 50)
                {
                    return Err("Choice must contain between 1 and 8 short options".to_string());
                }
            }
            UiElement::Progress {
                label,
                value,
                total,
            } => {
                if label.is_empty() || label.len() > 120 || value.len() > 50 || total.len() > 50 {
                    return Err("Progress declaration is invalid".to_string());
                }
            }
            UiElement::RecordList {
                bind_to,
                fields,
                search_binding,
                filter_binding,
                editable: _,
            } => {
                if bind_to.len() > 50
                    || fields.is_empty()
                    || fields.len() > 6
                    || fields
                        .iter()
                        .any(|field| field.is_empty() || field.len() > 50)
                    || search_binding
                        .as_ref()
                        .is_some_and(|value| value.len() > 50)
                    || filter_binding
                        .as_ref()
                        .is_some_and(|value| value.len() > 50)
                {
                    return Err("Record list declaration is invalid".to_string());
                }
            }
            UiElement::Breakdown {
                label,
                collection,
                amount_field,
                kinds,
            } => {
                if label.is_empty()
                    || label.len() > 120
                    || collection.len() > 50
                    || amount_field.len() > 50
                    || kinds.is_empty()
                    || kinds.len() > 8
                    || kinds.iter().any(|kind| kind.is_empty() || kind.len() > 50)
                {
                    return Err("Breakdown declaration is invalid".to_string());
                }
            }
            UiElement::Aggregate {
                label,
                collection,
                amount_field,
                positive_kinds,
                negative_kinds,
            } => {
                if label.is_empty()
                    || label.len() > 120
                    || collection.len() > 50
                    || amount_field.len() > 50
                    || positive_kinds.len() > 8
                    || negative_kinds.len() > 8
                    || (positive_kinds.is_empty() && negative_kinds.is_empty())
                {
                    return Err("Aggregate declaration is invalid".to_string());
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
            UiElement::Section { title, detail } => {
                if title.is_empty() || title.len() > 120 {
                    return Err("Section title must be between 1 and 120 characters".to_string());
                }
                if detail.as_ref().is_some_and(|value| value.len() > 300) {
                    return Err("Section detail too long. Maximum is 300 characters".to_string());
                }
            }
            UiElement::Metric { label, bind_to } | UiElement::Toggle { label, bind_to } => {
                if label.is_empty() || label.len() > 120 || bind_to.len() > 50 {
                    return Err("Metric or toggle declaration is invalid".to_string());
                }
            }
            UiElement::Divider => {}
        }

        Ok(())
    }
}

impl Action {
    pub fn validate(&self) -> Result<(), String> {
        match self {
            Action::Sequence { actions } => {
                if actions.len() > 20 {
                    return Err("Action sequence is too large. Maximum is 20 actions".to_string());
                }
                for action in actions {
                    action.validate()?;
                }
            }
            Action::Navigation { target } => {
                if target.len() > 50 {
                    return Err("Navigation target too long".to_string());
                }
            }
            Action::UpdateState { variable, value }
            | Action::AppendToList { variable, value }
            | Action::RemoveFromList { variable, value } => {
                if variable.len() > 50 {
                    return Err("State variable name too long".to_string());
                }
                if value.len() > 500 {
                    return Err("State value too long".to_string());
                }
            }
            Action::RemoveFirstFromList { variable } | Action::ClearList { variable } => {
                if variable.len() > 50 {
                    return Err("State variable name too long".to_string());
                }
            }
            Action::AppendRecord { variable, fields } => {
                if variable.len() > 50 || fields.is_empty() || fields.len() > 12 {
                    return Err("Record action is outside safe bounds".to_string());
                }
                if fields.iter().any(|field| {
                    field.name.is_empty() || field.name.len() > 50 || field.value.len() > 500
                }) {
                    return Err("Record field is outside safe bounds".to_string());
                }
            }
            Action::Increment { variable, by } => {
                if variable.len() > 50 || !(-1000..=1000).contains(by) {
                    return Err("Counter action is outside safe bounds".to_string());
                }
            }
            Action::SyncData { collection } => {
                if collection.is_empty() || collection.len() > 50 {
                    return Err("Collection name invalid".to_string());
                }
            }
            Action::NotifyUser { message } => {
                if message.is_empty() || message.len() > 500 {
                    return Err("Notification message invalid".to_string());
                }
            }
            Action::ScheduleReminder { message, time } => {
                if message.is_empty() || message.len() > 500 {
                    return Err("Reminder message must be between 1 and 500 characters".to_string());
                }
                if time.is_empty() || time.len() > 50 {
                    return Err("Reminder time must be between 1 and 50 characters".to_string());
                }
                if message.contains("eval")
                    || message.contains("exec")
                    || time.contains("eval")
                    || time.contains("exec")
                {
                    return Err("Reminder contains dangerous patterns".to_string());
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
            Action::If {
                condition,
                then,
                r#else: else_action,
            } => {
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
            Action::Loop {
                variable,
                range,
                body,
            } => {
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
