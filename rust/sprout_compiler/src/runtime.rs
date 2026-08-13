// Enhanced WASM Runtime with Security Sandbox

use crate::ast::*;
use anyhow::{Context, Result};
use std::collections::HashMap;
use std::time::{Duration, Instant};

#[derive(Debug, Clone)]
pub struct RuntimeOptions {
    pub max_execution_time: Duration,
    pub max_memory: usize,
    pub enable_debugging: bool,
}

impl Default for RuntimeOptions {
    fn default() -> Self {
        RuntimeOptions {
            max_execution_time: Duration::from_secs(10),
            max_memory: 1024 * 1024, // 1MB
            enable_debugging: false,
        }
    }
}

#[derive(Debug)]
pub struct WasmRuntime {
    state: HashMap<String, ValueType>,
    options: RuntimeOptions,
    execution_start: Instant,
    memory_usage: usize,
    execution_log: Vec<ExecutionEvent>,
    screens: HashMap<String, Screen>,
    screen_stack: Vec<String>,
}

#[derive(Debug, Clone)]
pub enum ExecutionEvent {
    ScreenLoaded(String),
    StateUpdated(String, ValueType),
    ReminderRequested { message: String, time: String },
    ActionExecuted(String),
    Error(String),
}

#[derive(Debug)]
pub struct ExecutionResult {
    pub success: bool,
    pub final_state: HashMap<String, ValueType>,
    pub execution_time: Duration,
    pub memory_usage: usize,
    pub events: Vec<ExecutionEvent>,
}

impl WasmRuntime {
    pub fn new(options: RuntimeOptions) -> Self {
        WasmRuntime {
            state: HashMap::new(),
            options,
            execution_start: Instant::now(),
            memory_usage: 0,
            execution_log: Vec::new(),
            screens: HashMap::new(),
            screen_stack: Vec::new(),
        }
    }

    pub fn execute(&mut self, app: &App, start_screen: &str) -> Result<ExecutionResult> {
        // Security: Reset execution state
        self.execution_start = Instant::now();
        self.memory_usage = 0;
        self.execution_log.clear();
        self.state.clear();
        self.screens = app
            .screens
            .iter()
            .cloned()
            .map(|screen| (screen.name.clone(), screen))
            .collect();
        self.screen_stack.clear();

        // Security: Validate app before execution
        app.validate()
            .map_err(|e| anyhow::anyhow!(e))
            .context("App validation failed")?;

        // Security: Initialize state
        for state_var in &app.state {
            self.update_state(&state_var.name, state_var.value.clone())?;
        }

        // Find start screen
        let screen = self
            .screens
            .get(start_screen)
            .cloned()
            .ok_or_else(|| anyhow::anyhow!("Start screen not found: {}", start_screen))?;

        // Security: Validate screen
        screen
            .validate()
            .map_err(|e| anyhow::anyhow!(e))
            .context("Screen validation failed")?;

        // Execute the initial screen. Button actions are dispatched only after
        // explicit interaction, never while the screen is being loaded.
        self.screen_stack.push(screen.name.clone());
        self.execute_screen(&screen)?;

        // Security: Check execution time
        let elapsed = self.execution_start.elapsed();
        if elapsed > self.options.max_execution_time {
            return Err(anyhow::anyhow!("Execution timeout: {:?}", elapsed));
        }

        // Security: Check memory usage
        if self.memory_usage > self.options.max_memory {
            return Err(anyhow::anyhow!(
                "Memory limit exceeded: {}",
                self.memory_usage
            ));
        }

        Ok(ExecutionResult {
            success: true,
            final_state: self.state.clone(),
            execution_time: elapsed,
            memory_usage: self.memory_usage,
            events: self.execution_log.clone(),
        })
    }

    fn execute_screen(&mut self, screen: &Screen) -> Result<()> {
        // Security: Log screen load
        self.log_event(ExecutionEvent::ScreenLoaded(screen.name.clone()));

        // Initialize screen state
        for state_var in &screen.state {
            self.update_state(&state_var.name, state_var.value.clone())?;
        }

        // Execute UI elements
        for ui_element in &screen.ui {
            self.execute_ui_element(ui_element)?;
        }

        Ok(())
    }

    fn execute_ui_element(&mut self, ui_element: &UiElement) -> Result<()> {
        match ui_element {
            UiElement::Label { text } => {
                // Security: Evaluate string interpolation
                let _evaluated = self.evaluate_expression(text)?;
                self.track_memory_usage(text.len());
            }
            UiElement::Button { label, action } => {
                // Validate actions at load time, but execute them only after a
                // user interaction through `dispatch_action`.
                action.validate().map_err(|e| anyhow::anyhow!(e))?;
                self.track_memory_usage(label.len() + 100); // Estimate button memory
            }
            UiElement::TextField {
                placeholder,
                bind_to,
            } => {
                self.track_memory_usage(placeholder.len());
                // Security: Track binding variable
                if !self.state.contains_key(bind_to) {
                    self.update_state(bind_to, ValueType::String(String::new()))?;
                }
            }
            UiElement::Image { source } => {
                // Security: Validate image source
                if source.starts_with("http://") && !source.starts_with("http://localhost") {
                    return Err(anyhow::anyhow!("Insecure HTTP connection not allowed"));
                }
                self.track_memory_usage(source.len() + 1024); // Estimate image memory
            }
            UiElement::List { items, bind_to } => {
                for item in items {
                    self.track_memory_usage(item.len());
                }
                // Security: Track list binding
                if !self.state.contains_key(bind_to) {
                    self.update_state(bind_to, ValueType::Array(vec![]))?;
                }
            }
        }

        Ok(())
    }

    fn execute_action(&mut self, action: &Action) -> Result<()> {
        // Security: Log action execution
        self.log_event(ExecutionEvent::ActionExecuted(format!("{:?}", action)));

        match action {
            Action::Sequence { actions } => {
                for action in actions {
                    self.execute_action(action)?;
                }
            }
            Action::Navigation { target } => self.navigate_to(target)?,
            Action::UpdateState { variable, value } => {
                let evaluated = self.evaluate_expression(value)?;
                self.update_state(variable, evaluated)?;
            }
            Action::AppendToList { variable, value } => {
                let evaluated = self.evaluate_expression(value)?;
                let mut values = match self.state.get(variable) {
                    Some(ValueType::Array(values)) => values.clone(),
                    Some(_) => {
                        return Err(anyhow::anyhow!(
                            "State variable is not a list: {}",
                            variable
                        ))
                    }
                    None => Vec::new(),
                };
                if values.len() >= 100 {
                    return Err(anyhow::anyhow!("List is full: {}", variable));
                }
                values.push(evaluated);
                self.update_state(variable, ValueType::Array(values))?;
            }
            Action::RemoveFromList { variable, value } => {
                let evaluated = self.evaluate_expression(value)?;
                let mut values = match self.state.get(variable) {
                    Some(ValueType::Array(values)) => values.clone(),
                    Some(_) => {
                        return Err(anyhow::anyhow!(
                            "State variable is not a list: {}",
                            variable
                        ))
                    }
                    None => Vec::new(),
                };
                if let Some(position) = values.iter().position(|item| item == &evaluated) {
                    values.remove(position);
                }
                self.update_state(variable, ValueType::Array(values))?;
            }
            Action::ScheduleReminder { message, time } => {
                let message = Self::stringify_value(&self.evaluate_expression(message)?);
                let time = Self::stringify_value(&self.evaluate_expression(time)?);
                self.log_event(ExecutionEvent::ReminderRequested { message, time });
            }
            Action::RemoveFirstFromList { variable } => {
                let mut values = match self.state.get(variable) {
                    Some(ValueType::Array(values)) => values.clone(),
                    Some(_) => {
                        return Err(anyhow::anyhow!(
                            "State variable is not a list: {}",
                            variable
                        ))
                    }
                    None => Vec::new(),
                };
                if !values.is_empty() {
                    values.remove(0);
                }
                self.update_state(variable, ValueType::Array(values))?;
            }
            Action::CallFunction { function, args } => {
                // Security: Check for dangerous function calls
                if function.contains("eval") || function.contains("exec") {
                    return Err(anyhow::anyhow!(
                        "Dangerous function call detected: {}",
                        function
                    ));
                }

                // Security: Limit number of arguments
                if args.len() > 10 {
                    return Err(anyhow::anyhow!("Too many arguments: {}", args.len()));
                }

                for arg in args {
                    self.evaluate_expression(arg)?;
                }
            }
            Action::If {
                condition,
                then,
                r#else: else_action,
            } => {
                // Security: Evaluate condition
                let condition_result = self.evaluate_condition(condition)?;

                if condition_result {
                    self.execute_action(then)?;
                } else if let Some(else_act) = else_action {
                    self.execute_action(else_act)?;
                }
            }
            Action::Loop {
                variable,
                range,
                body,
            } => {
                // Security: Limit loop iterations
                if body.len() > 100 {
                    return Err(anyhow::anyhow!("Loop body too large"));
                }

                // Security: Parse range and limit iterations
                let range_values: Vec<i64> = range
                    .split("..")
                    .filter_map(|s| s.trim().parse().ok())
                    .collect();

                if range_values.len() != 2 {
                    return Err(anyhow::anyhow!("Invalid range format"));
                }

                let start = range_values[0].min(range_values[1]);
                let end = range_values[0].max(range_values[1]);
                let max_iterations = (end - start + 1).min(100) as usize; // Max 100 iterations

                for i in start..start + max_iterations as i64 {
                    // Security: Update loop variable
                    self.update_state(variable, ValueType::Number(i))?;

                    // Security: Execute loop body
                    for action in body {
                        self.execute_action(action)?;
                    }
                }
            }
        }

        Ok(())
    }

    fn navigate_to(&mut self, target: &str) -> Result<()> {
        if target == "Back" {
            if self.screen_stack.len() > 1 {
                self.screen_stack.pop();
                let previous = self
                    .screen_stack
                    .last()
                    .cloned()
                    .ok_or_else(|| anyhow::anyhow!("Navigation stack is empty"))?;
                let screen = self
                    .screens
                    .get(&previous)
                    .cloned()
                    .ok_or_else(|| anyhow::anyhow!("Screen not found: {}", previous))?;
                self.execute_screen(&screen)?;
            }
            return Ok(());
        }

        let screen = self
            .screens
            .get(target)
            .cloned()
            .ok_or_else(|| anyhow::anyhow!("Navigation target not found: {}", target))?;
        self.screen_stack.push(screen.name.clone());
        self.execute_screen(&screen)
    }

    /// Dispatches an already-validated UI action after a user interaction.
    pub fn dispatch_action(&mut self, action: &Action) -> Result<()> {
        action.validate().map_err(|error| anyhow::anyhow!(error))?;
        self.execute_action(action)?;
        if self.execution_start.elapsed() > self.options.max_execution_time {
            return Err(anyhow::anyhow!("Execution timeout"));
        }
        if self.memory_usage > self.options.max_memory {
            return Err(anyhow::anyhow!("Memory limit exceeded"));
        }
        Ok(())
    }

    pub fn state_value(&self, name: &str) -> Option<&ValueType> {
        self.state.get(name)
    }

    pub fn current_screen(&self) -> Option<&str> {
        self.screen_stack.last().map(String::as_str)
    }

    fn update_state(&mut self, name: &str, value: ValueType) -> Result<()> {
        // Security: Validate state variable name
        if name.len() > 50 {
            return Err(anyhow::anyhow!("State variable name too long"));
        }

        // Security: Check for dangerous patterns
        if name.contains("eval") || name.contains("exec") {
            return Err(anyhow::anyhow!("Dangerous variable name: {}", name));
        }

        // Security: Validate value size
        match &value {
            ValueType::String(s) => {
                if s.len() > 1000 {
                    return Err(anyhow::anyhow!("String value too long"));
                }
                self.track_memory_usage(s.len());
            }
            ValueType::Array(arr) => {
                if arr.len() > 100 {
                    return Err(anyhow::anyhow!("Array too large"));
                }
                self.track_memory_usage(arr.len() * 8);
            }
            ValueType::Object(obj) if obj.len() > 50 => {
                return Err(anyhow::anyhow!("Object too large"));
            }
            _ => {}
        }

        self.state.insert(name.to_string(), value.clone());
        self.log_event(ExecutionEvent::StateUpdated(name.to_string(), value));

        Ok(())
    }

    fn stringify_value(value: &ValueType) -> String {
        match value {
            ValueType::String(value) => value.clone(),
            ValueType::Number(value) => value.to_string(),
            ValueType::Boolean(value) => value.to_string(),
            ValueType::Array(values) => format!("{values:?}"),
            ValueType::Object(values) => format!("{values:?}"),
        }
    }

    fn evaluate_expression(&self, expression: &str) -> Result<ValueType> {
        // Security: Check for dangerous patterns
        if expression.contains("eval") || expression.contains("exec") {
            return Err(anyhow::anyhow!("Dangerous expression detected"));
        }

        // Security: Evaluate simple expressions
        let trimmed = expression.trim();

        // Boolean literals
        if trimmed == "true" {
            return Ok(ValueType::Boolean(true));
        }
        if trimmed == "false" {
            return Ok(ValueType::Boolean(false));
        }

        // Number literals
        if let Ok(num) = trimmed.parse::<i64>() {
            return Ok(ValueType::Number(num));
        }

        // String literals
        if trimmed.starts_with('"') && trimmed.ends_with('"') {
            let text = &trimmed[1..trimmed.len() - 1];
            return Ok(ValueType::String(text.to_string()));
        }

        // Variable references
        if let Some(value) = self.state.get(trimmed) {
            return Ok(value.clone());
        }

        // Default: treat as string
        Ok(ValueType::String(trimmed.to_string()))
    }

    fn evaluate_condition(&self, condition: &str) -> Result<bool> {
        // Security: Check for dangerous patterns
        if condition.contains("eval") || condition.contains("exec") {
            return Err(anyhow::anyhow!("Dangerous condition detected"));
        }

        // Security: Simple condition evaluation
        let trimmed = condition.trim();

        // Direct boolean
        if trimmed == "true" {
            return Ok(true);
        }
        if trimmed == "false" {
            return Ok(false);
        }

        // Number comparison
        if let Some(pos) = trimmed.find("==") {
            let left = &trimmed[..pos].trim();
            let right = &trimmed[pos + 2..].trim();

            if let (Ok(left_val), Ok(right_val)) = (left.parse::<i64>(), right.parse::<i64>()) {
                return Ok(left_val == right_val);
            }
        }

        // String comparison
        if let Some(pos) = trimmed.find("==") {
            let left = &trimmed[..pos].trim();
            let right = &trimmed[pos + 2..].trim();

            if left.starts_with('"')
                && left.ends_with('"')
                && right.starts_with('"')
                && right.ends_with('"')
            {
                let left_str = &left[1..left.len() - 1];
                let right_str = &right[1..right.len() - 1];
                return Ok(left_str == right_str);
            }
        }

        // Default: false for safety
        Ok(false)
    }

    fn track_memory_usage(&mut self, bytes: usize) {
        self.memory_usage += bytes;

        // Security: Check memory limit
        if self.memory_usage > self.options.max_memory {
            self.log_event(ExecutionEvent::Error("Memory limit exceeded".to_string()));
        }
    }

    fn log_event(&mut self, event: ExecutionEvent) {
        // Security: Limit event log size
        if self.execution_log.len() < 1000 {
            self.execution_log.push(event);
        }
    }

    // Security: Get execution statistics
    pub fn get_statistics(&self) -> RuntimeStatistics {
        RuntimeStatistics {
            execution_time: self.execution_start.elapsed(),
            memory_usage: self.memory_usage,
            state_variables: self.state.len(),
            events_logged: self.execution_log.len(),
        }
    }
}

#[derive(Debug)]
pub struct RuntimeStatistics {
    pub execution_time: Duration,
    pub memory_usage: usize,
    pub state_variables: usize,
    pub events_logged: usize,
}

// Public execute function
pub fn execute_sprout_app(
    app: &App,
    start_screen: &str,
    options: Option<RuntimeOptions>,
) -> Result<ExecutionResult> {
    let runtime_options = options.unwrap_or_default();
    let mut runtime = WasmRuntime::new(runtime_options);
    runtime.execute(app, start_screen)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn app_with_ui(ui: Vec<UiElement>) -> App {
        App {
            name: "Test".to_string(),
            start_screen: "Home".to_string(),
            screens: vec![Screen {
                name: "Home".to_string(),
                state: vec![],
                ui,
            }],
            state: vec![],
        }
    }

    #[test]
    fn test_execute_simple_app() {
        let app = app_with_ui(vec![UiElement::Label {
            text: "Hello".to_string(),
        }]);

        let result = execute_sprout_app(&app, "Home", None).expect("valid app should execute");
        assert!(result.success);
        assert!(matches!(
            result.events.first(),
            Some(ExecutionEvent::ScreenLoaded(name)) if name == "Home"
        ));
    }

    #[test]
    fn test_security_rejects_dangerous_function_call() {
        let app = app_with_ui(vec![UiElement::Button {
            label: "Run".to_string(),
            action: Action::CallFunction {
                function: "eval".to_string(),
                args: vec![],
            },
        }]);

        let error = execute_sprout_app(&app, "Home", None)
            .expect_err("dangerous functions must be rejected");
        assert!(format!("{error:#}").contains("Dangerous function call"));
    }

    #[test]
    fn test_interactive_todo_mutation_and_navigation() {
        let app = App {
            name: "Todo".to_string(),
            start_screen: "Todo".to_string(),
            state: vec![],
            screens: vec![
                Screen {
                    name: "Todo".to_string(),
                    state: vec![
                        StateVariable {
                            name: "draft".to_string(),
                            value: ValueType::String(String::new()),
                        },
                        StateVariable {
                            name: "todos".to_string(),
                            value: ValueType::Array(vec![]),
                        },
                    ],
                    ui: vec![],
                },
                Screen {
                    name: "Settings".to_string(),
                    state: vec![],
                    ui: vec![],
                },
            ],
        };
        let mut runtime = WasmRuntime::new(RuntimeOptions::default());
        runtime.execute(&app, "Todo").expect("app starts");

        runtime
            .dispatch_action(&Action::UpdateState {
                variable: "draft".to_string(),
                value: "\"Buy milk\"".to_string(),
            })
            .expect("input updates draft");
        runtime
            .dispatch_action(&Action::Sequence {
                actions: vec![
                    Action::AppendToList {
                        variable: "todos".to_string(),
                        value: "draft".to_string(),
                    },
                    Action::UpdateState {
                        variable: "draft".to_string(),
                        value: "\"\"".to_string(),
                    },
                ],
            })
            .expect("todo is appended");
        assert_eq!(
            runtime.state_value("todos"),
            Some(&ValueType::Array(vec![ValueType::String(
                "Buy milk".to_string()
            )]))
        );

        runtime
            .dispatch_action(&Action::Navigation {
                target: "Settings".to_string(),
            })
            .expect("settings opens");
        assert_eq!(runtime.current_screen(), Some("Settings"));
        runtime
            .dispatch_action(&Action::Navigation {
                target: "Back".to_string(),
            })
            .expect("back returns to todo");
        assert_eq!(runtime.current_screen(), Some("Todo"));

        runtime
            .dispatch_action(&Action::RemoveFirstFromList {
                variable: "todos".to_string(),
            })
            .expect("completed todo is removed");
        assert_eq!(
            runtime.state_value("todos"),
            Some(&ValueType::Array(vec![]))
        );
    }
}
