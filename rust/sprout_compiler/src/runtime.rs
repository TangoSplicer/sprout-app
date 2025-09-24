// rust/sprout_compiler/src/runtime.rs
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use std::fmt;

/// Runtime for executing SproutScript applications
pub struct SproutRuntime {
    state: HashMap<String, Value>,
    listeners: Vec<StateListener>,
    history: Vec<StateChange>,
    max_history: usize,
}

/// Represents a value in the runtime
#[derive(Debug, Clone)]
pub enum Value {
    Number(f64),
    String(String),
    Boolean(bool),
    List(Vec<Value>),
    Object(HashMap<String, Value>),
    Null,
}

/// Represents a change in state
#[derive(Debug, Clone)]
pub struct StateChange {
    key: String,
    old_value: Option<Value>,
    new_value: Value,
    timestamp: std::time::SystemTime,
}

/// Type for state change listeners
type StateListener = Box<dyn Fn(&str, &Value) + Send + Sync>;

/// Runtime errors
#[derive(Debug)]
pub enum RuntimeError {
    InvalidOperation(String),
    TypeMismatch(String),
    UndefinedVariable(String),
    ExecutionError(String),
}

impl fmt::Display for RuntimeError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            RuntimeError::InvalidOperation(msg) => write!(f, "Invalid operation: {}", msg),
            RuntimeError::TypeMismatch(msg) => write!(f, "Type mismatch: {}", msg),
            RuntimeError::UndefinedVariable(name) => write!(f, "Undefined variable: {}", name),
            RuntimeError::ExecutionError(msg) => write!(f, "Execution error: {}", msg),
        }
    }
}

impl std::error::Error for RuntimeError {}

impl SproutRuntime {
    /// Create a new runtime instance
    pub fn new() -> Self {
        Self {
            state: HashMap::new(),
            listeners: Vec::new(),
            history: Vec::new(),
            max_history: 100,
        }
    }

    /// Set a state variable
    pub fn set(&mut self, name: &str, value: Value) {
        let old_value = self.state.get(name).cloned();
        
        // Record the change in history
        self.history.push(StateChange {
            key: name.to_string(),
            old_value,
            new_value: value.clone(),
            timestamp: std::time::SystemTime::now(),
        });
        
        // Trim history if needed
        if self.history.len() > self.max_history {
            self.history.remove(0);
        }
        
        // Update the state
        self.state.insert(name.to_string(), value.clone());
        
        // Notify listeners
        for listener in &self.listeners {
            listener(name, &value);
        }
    }

    /// Get a state variable
    pub fn get(&self, name: &str) -> Option<&Value> {
        self.state.get(name)
    }

    /// Add a listener for state changes
    pub fn add_listener<F>(&mut self, listener: F)
    where
        F: Fn(&str, &Value) + Send + Sync + 'static,
    {
        self.listeners.push(Box::new(listener));
    }

    /// Run an action
    pub fn run_action(&mut self, code: &str) -> Result<(), RuntimeError> {
        // Simple action parser
        if code.contains("++") {
            // Counter increment
            let var_name = code.split("++").next().unwrap_or("").trim();
            if var_name.is_empty() {
                return Err(RuntimeError::InvalidOperation("Missing variable name for increment".to_string()));
            }
            
            match self.get(var_name) {
                Some(Value::Number(n)) => {
                    self.set(var_name, Value::Number(n + 1.0));
                    Ok(())
                }
                Some(_) => Err(RuntimeError::TypeMismatch(format!("{} is not a number", var_name))),
                None => Err(RuntimeError::UndefinedVariable(var_name.to_string())),
            }
        } else if code.contains("--") {
            // Counter decrement
            let var_name = code.split("--").next().unwrap_or("").trim();
            if var_name.is_empty() {
                return Err(RuntimeError::InvalidOperation("Missing variable name for decrement".to_string()));
            }
            
            match self.get(var_name) {
                Some(Value::Number(n)) => {
                    self.set(var_name, Value::Number(n - 1.0));
                    Ok(())
                }
                Some(_) => Err(RuntimeError::TypeMismatch(format!("{} is not a number", var_name))),
                None => Err(RuntimeError::UndefinedVariable(var_name.to_string())),
            }
        } else if code.contains("=") {
            // Assignment
            let parts: Vec<&str> = code.split('=').collect();
            if parts.len() != 2 {
                return Err(RuntimeError::InvalidOperation("Invalid assignment".to_string()));
            }
            
            let var_name = parts[0].trim();
            let value_str = parts[1].trim();
            
            // Parse the value
            let value = self.parse_value(value_str)?;
            self.set(var_name, value);
            Ok(())
        } else {
            Err(RuntimeError::InvalidOperation(format!("Unsupported action: {}", code)))
        }
    }
    
    /// Parse a value from a string
    fn parse_value(&self, value_str: &str) -> Result<Value, RuntimeError> {
        // Try to parse as number
        if let Ok(n) = value_str.parse::<f64>() {
            return Ok(Value::Number(n));
        }
        
        // Check for boolean
        if value_str == "true" {
            return Ok(Value::Boolean(true));
        }
        if value_str == "false" {
            return Ok(Value::Boolean(false));
        }
        
        // Check for null
        if value_str == "null" {
            return Ok(Value::Null);
        }
        
        // Check for string literal
        if value_str.starts_with('"') && value_str.ends_with('"') {
            return Ok(Value::String(value_str[1..value_str.len()-1].to_string()));
        }
        
        // Check if it's a variable reference
        if let Some(value) = self.get(value_str) {
            return Ok(value.clone());
        }
        
        // Default to string
        Ok(Value::String(value_str.to_string()))
    }
    
    /// Get the state change history
    pub fn get_history(&self) -> &[StateChange] {
        &self.history
    }
    
    /// Clear the state
    pub fn clear(&mut self) {
        self.state.clear();
        self.history.clear();
    }
    
    /// Get all state variables
    pub fn get_all_state(&self) -> &HashMap<String, Value> {
        &self.state
    }
    
    /// Create a thread-safe shared runtime
    pub fn shared() -> Arc<Mutex<Self>> {
        Arc::new(Mutex::new(Self::new()))
    }
}