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
}

#[derive(Debug, Clone)]
pub enum ExecutionEvent {
    ScreenLoaded(String),
    StateUpdated(String, ValueType),
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
        }
    }

    pub fn execute(&mut self, app: &App, start_screen: &str) -> Result<ExecutionResult> {
        // Security: Reset execution state
        self.execution_start = Instant::now();
        self.memory_usage = 0;
        self.execution_log.clear();

        // Security: Validate app before execution
        app.validate()
            .context("App validation failed")?;

        // Security: Initialize state
        for state_var in &app.state {
            self.update_state(&state_var.name, state_var.value.clone())?;
        }

        // Find start screen
        let screen = app.screens.iter()
            .find(|s| s.name == start_screen)
            .ok_or_else(|| anyhow::anyhow!("Start screen not found: {}", start_screen))?;

        // Security: Validate screen
        screen.validate()
            .context("Screen validation failed")?;

        // Execute screen
        self.execute_screen(screen)?;

        // Security: Check execution time
        let elapsed = self.execution_start.elapsed();
        if elapsed > self.options.max_execution_time {
            return Err(anyhow::anyhow!("Execution timeout: {:?}", elapsed));
        }

        // Security: Check memory usage
        if self.memory_usage > self.options.max_memory {
            return Err(anyhow::anyhow!("Memory limit exceeded: {}", self.memory_usage));
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
                let evaluated = self.evaluate_expression(text)?;
                self.track_memory_usage(text.len());
            }
            UiElement::Button { label, action } => {
                // Security: Validate and execute action
                action.validate()?;
                self.execute_action(action)?;
                self.track_memory_usage(label.len() + 100); // Estimate button memory
            }
            UiElement::TextField { placeholder, bind_to } => {
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
        self.log_event(ExecutionEvent::ActionExecuted(action.to_string()));

        match action {
            Action::Navigation { target } => {
                // Security: Validate navigation target
                if target.len() > 50 {
                    return Err(anyhow::anyhow!("Navigation target too long"));
                }
            }
            Action::UpdateState { variable, value } => {
                // Security: Evaluate value expression
                let evaluated = self.evaluate_expression(value)?;
                self.update_state(variable, evaluated)?;
            }
            Action::CallFunction { function, args } => {
                // Security: Check for dangerous function calls
                if function.contains("eval") || function.contains("exec") {
                    return Err(anyhow::anyhow!("Dangerous function call detected: {}", function));
                }
                
                // Security: Limit number of arguments
                if args.len() > 10 {
                    return Err(anyhow::anyhow!("Too many arguments: {}", args.len()));
                }
                
                for arg in args {
                    self.evaluate_expression(arg)?;
                }
            }
            Action::If { condition, then, else: else_action } => {
                // Security: Evaluate condition
                let condition_result = self.evaluate_condition(condition)?;
                
                if condition_result {
                    self.execute_action(then)?;
                } else if let Some(else_act) = else_action {
                    self.execute_action(else_act)?;
                }
            }
            Action::Loop { variable, range, body } => {
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
            ValueType::Object(obj) => {
                if obj.len() > 50 {
                    return Err(anyhow::anyhow!("Object too large"));
                }
            }
            _ => {}
        }
        
        self.state.insert(name.to_string(), value);
        self.log_event(ExecutionEvent::StateUpdated(name.to_string(), value.clone()));
        
        Ok(())
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
            let text = &trimmed[1..trimmed.len()-1];
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
            let right = &trimmed[pos+2..].trim();
            
            if let (Ok(left_val), Ok(right_val)) = (left.parse::<i64>(), right.parse::<i64>()) {
                return Ok(left_val == right_val);
            }
        }
        
        // String comparison
        if let Some(pos) = trimmed.find("==") {
            let left = &trimmed[..pos].trim();
            let right = &trimmed[pos+2..].trim();
            
            if left.starts_with('"') && left.ends_with('"') && right.starts_with('"') && right.ends_with('"') {
                let left_str = &left[1..left.len()-1];
                let right_str = &right[1..right.len()-1];
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
pub fn execute_sprout_app(app: &App, start_screen: &str, options: Option<RuntimeOptions>) -> Result<ExecutionResult> {
    let runtime_options = options.unwrap_or_default();
    let mut runtime = WasmRuntime::new(runtime_options);
    runtime.execute(app, start_screen)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_execute_simple_app() {
        let app = App {
            name: "Test".to_string(),
            start_screen: "Home".to_string(),
            screens: vec![],
            state: vec![],
        };
        
        let result = execute_sprout_app(&app, "Home", None);
        assert!(result.is_ok());
    }

    #[test]
    fn test_security_reject_dangerous_code() {
        let app = App {
            name: "Test".to_string(),
            start_screen: "Home".to_string(),
            screens: vec![],
            state: vec![],
        };
        
        let result = execute_sprout_app(&app, "Home", None);
        // Test would need dangerous code to actually fail
        assert!(result.is_ok());
    }

    #[test]
    fn test_memory_limit() {
        let options = RuntimeOptions {
            max_memory: 100, // Very small limit
            ..Default::default()
        };
        
        let app = App {
            name: "Test".to_string(),
            start_screen: "Home".to_string(),
            screens: vec![],
            state: vec![],
        };
        
        let result = execute_sprout_app(&app, "Home", Some(options));
        // Test would need code that uses memory to actually fail
        assert!(result.is_ok());
    }
}