use crate::ast::*;
use std::collections::HashSet;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum SecurityError {
    #[error("Dangerous function call: {function}")]
    DangerousFunction { function: String },
    #[error("Unsafe import: {import}")]
    UnsafeImport { import: String },
    #[error("Resource limit exceeded: {resource} ({current} > {limit})")]
    ResourceLimit { resource: String, current: usize, limit: usize },
    #[error("Permission violation: {permission} required")]
    PermissionViolation { permission: String },
    #[error("Code complexity too high: {complexity}")]
    ComplexityLimit { complexity: usize },
    #[error("Unsafe data access: {details}")]
    UnsafeDataAccess { details: String },
}

pub struct SecurityAnalyzer {
    pub blocked_functions: HashSet<String>,
    pub allowed_imports: HashSet<String>,
    pub resource_limits: ResourceLimits,
    pub max_complexity: usize,
}

#[derive(Debug, Clone)]
pub struct ResourceLimits {
    pub max_screens: usize,
    pub max_state_vars: usize,
    pub max_nesting_depth: usize,
    pub max_string_length: usize,
    pub max_function_calls: usize,
    pub max_ui_elements: usize,
}

impl Default for ResourceLimits {
    fn default() -> Self {
        Self {
            max_screens: 50,
            max_state_vars: 100,
            max_nesting_depth: 10,
            max_string_length: 10000,
            max_function_calls: 200,
            max_ui_elements: 500,
        }
    }
}

impl Default for SecurityAnalyzer {
    fn default() -> Self {
        let mut blocked_functions = HashSet::new();
        // Core dangerous functions
        blocked_functions.insert("eval".to_string());
        blocked_functions.insert("exec".to_string());
        blocked_functions.insert("system".to_string());
        blocked_functions.insert("shell".to_string());
        blocked_functions.insert("__import__".to_string());
        blocked_functions.insert("getattr".to_string());
        blocked_functions.insert("setattr".to_string());
        blocked_functions.insert("compile".to_string());
        blocked_functions.insert("globals".to_string());
        blocked_functions.insert("locals".to_string());
        // File system access
        blocked_functions.insert("open".to_string());
        blocked_functions.insert("file".to_string());
        blocked_functions.insert("read".to_string());
        blocked_functions.insert("write".to_string());
        // Network access
        blocked_functions.insert("fetch".to_string());
        blocked_functions.insert("request".to_string());
        blocked_functions.insert("http".to_string());
        blocked_functions.insert("socket".to_string());
        // Process manipulation
        blocked_functions.insert("spawn".to_string());
        blocked_functions.insert("fork".to_string());
        blocked_functions.insert("thread".to_string());
        
        let mut allowed_imports = HashSet::new();
        allowed_imports.insert("@sprout/ui".to_string());
        allowed_imports.insert("@sprout/data".to_string());
        allowed_imports.insert("@sprout/utils".to_string());
        allowed_imports.insert("@sprout/widgets".to_string());
        allowed_imports.insert("@sprout/animation".to_string());
        
        Self {
            blocked_functions,
            allowed_imports,
            resource_limits: ResourceLimits::default(),
            max_complexity: 20,
        }
    }
}

impl SecurityAnalyzer {
    pub fn new_with_level(level: SecurityLevel) -> Self {
        let mut analyzer = Self::default();
        
        match level {
            SecurityLevel::Strict => {
                // Default is already strict
            },
            SecurityLevel::Moderate => {
                // Remove some restrictions
                analyzer.blocked_functions.remove("getattr");
                analyzer.blocked_functions.remove("setattr");
                analyzer.resource_limits.max_nesting_depth = 15;
                analyzer.max_complexity = 30;
            },
            SecurityLevel::Permissive => {
                // Minimal restrictions
                analyzer.blocked_functions.retain(|f| {
                    matches!(f.as_str(), "eval" | "exec" | "system" | "shell")
                });
                analyzer.resource_limits.max_nesting_depth = 25;
                analyzer.max_complexity = 50;
            }
        }
        
        analyzer
    }
    
    pub fn analyze_app(&self, app: &App) -> Result<SecurityReport, SecurityError> {
        let mut report = SecurityReport::default();
        
        // Check resource limits
        self.check_resource_limits(app, &mut report)?;
        
        // Analyze imports
        self.analyze_imports(&app.imports, &mut report)?;
        
        // Analyze screens
        for screen in &app.screens {
            self.analyze_screen(screen, &mut report)?;
        }
        
        // Calculate overall complexity
        let complexity = self.calculate_complexity(app);
        if complexity > self.max_complexity {
            return Err(SecurityError::ComplexityLimit { complexity });
        }
        
        // Finalize report
        report.complexity_score = complexity;
        report.risk_level = self.calculate_risk_level(&report);
        
        Ok(report)
    }
    
    fn check_resource_limits(&self, app: &App, report: &mut SecurityReport) -> Result<(), SecurityError> {
        // Check screen count
        if app.screens.len() > self.resource_limits.max_screens {
            return Err(SecurityError::ResourceLimit {
                resource: "screens".to_string(),
                current: app.screens.len(),
                limit: self.resource_limits.max_screens,
            });
        }
        
        // Check state variable count and UI elements per screen
        let mut total_ui_elements = 0;
        for screen in &app.screens {
            if screen.state.len() > self.resource_limits.max_state_vars {
                return Err(SecurityError::ResourceLimit {
                    resource: format!("state variables in screen '{}'", screen.name),
                    current: screen.state.len(),
                    limit: self.resource_limits.max_state_vars,
                });
            }
            
            let ui_count = self.count_ui_elements(&screen.ui);
            total_ui_elements += ui_count;
            
            if ui_count > self.resource_limits.max_ui_elements {
                return Err(SecurityError::ResourceLimit {
                    resource: format!("UI elements in screen '{}'", screen.name),
                    current: ui_count,
                    limit: self.resource_limits.max_ui_elements,
                });
            }
        }
        
        report.total_ui_elements = total_ui_elements;
        Ok(())
    }
    
    fn count_ui_elements(&self, ui: &UI) -> usize {
        match ui {
            UI::Column(children) | UI::Row(children) | UI::Stack(children) => {
                1 + children.iter().map(|child| self.count_ui_elements(child)).sum::<usize>()
            },
            UI::List { child, .. } => 1 + self.count_ui_elements(child),
            UI::Conditional { then_branch, else_branch, .. } => {
                let mut count = 1 + self.count_ui_elements(then_branch);
                if let Some(else_branch) = else_branch {
                    count += self.count_ui_elements(else_branch);
                }
                count
            },
            _ => 1,
        }
    }
    
    fn analyze_imports(&self, imports: &[Import], report: &mut SecurityReport) -> Result<(), SecurityError> {
        for import in imports {
            if !self.allowed_imports.contains(&import.path) {
                return Err(SecurityError::UnsafeImport {
                    import: import.path.clone(),
                });
            }
            report.required_imports.insert(import.path.clone());
        }
        Ok(())
    }
    
    fn analyze_screen(&self, screen: &Screen, report: &mut SecurityReport) -> Result<(), SecurityError> {
        // Analyze state declarations
        for state in &screen.state {
            self.analyze_expression(&state.value, report, 0)?;
        }
        
        // Analyze UI tree with depth tracking
        self.analyze_ui(&screen.ui, report, 0)?;
        
        // Analyze actions
        for action in &screen.actions {
            self.analyze_action_code(&action.code, report)?;
        }
        
        Ok(())
    }
    
    fn analyze_ui(&self, ui: &UI, report: &mut SecurityReport, depth: usize) -> Result<(), SecurityError> {
        // Check nesting depth
        if depth > self.resource_limits.max_nesting_depth {
            return Err(SecurityError::ResourceLimit {
                resource: "UI nesting depth".to_string(),
                current: depth,
                limit: self.resource_limits.max_nesting_depth,
            });
        }
        
        match ui {
            UI::Column(children) | UI::Row(children) | UI::Stack(children) => {
                for child in children {
                    self.analyze_ui(child, report, depth + 1)?;
                }
            },
            UI::Button { action: Some(action), navigate, .. } => {
                self.analyze_action_code(action, report)?;
                if let Some(nav) = navigate {
                    report.navigation_targets.insert(nav.screen.clone());
                    for arg in &nav.args {
                        self.analyze_expression(arg, report, depth)?;
                    }
                }
            },
            UI::Image { src } => {
                // Check image source security
                if src.starts_with("http://") {
                    report.security_warnings.push("Insecure HTTP image source detected".to_string());
                }
                if src.starts_with("https://") {
                    report.external_resources.insert(src.clone());
                }
                if src.contains("javascript:") || src.contains("data:") {
                    return Err(SecurityError::UnsafeDataAccess {
                        details: "Dangerous image source scheme detected".to_string(),
                    });
                }
                report.required_permissions.insert("READ_EXTERNAL_STORAGE".to_string());
            },
            UI::Input { binding, label } => {
                // Input security checks
                report.accessed_state.insert(binding.clone());
                
                // Check for sensitive input patterns
                let label_lower = label.to_lowercase();
                if label_lower.contains("password") || label_lower.contains("secret") {
                    report.sensitive_inputs.insert(binding.clone());
                }
                
                self.validate_state_access(binding, report)?;
            },
            UI::List { child, items } => {
                self.analyze_ui(child, report, depth + 1)?;
                report.accessed_state.insert(items.clone());
                self.validate_state_access(items, report)?;
            },
            UI::Conditional { condition, then_branch, else_branch, .. } => {
                self.analyze_expression(condition, report, depth)?;
                self.analyze_ui(then_branch, report, depth + 1)?;
                if let Some(else_branch) = else_branch {
                    self.analyze_ui(else_branch, report, depth + 1)?;
                }
            },
            UI::Label(content) | UI::Title(content) => {
                // Check string length and content
                if content.len() > self.resource_limits.max_string_length {
                    return Err(SecurityError::ResourceLimit {
                        resource: "string length".to_string(),
                        current: content.len(),
                        limit: self.resource_limits.max_string_length,
                    });
                }
                
                // Check for script injection attempts
                if content.contains("<script") || content.contains("javascript:") {
                    return Err(SecurityError::UnsafeDataAccess {
                        details: "Script injection attempt detected in text".to_string(),
                    });
                }
            },
            UI::CustomComponent { name, props } => {
                // Validate custom component security
                if !self.is_safe_component_name(name) {
                    return Err(SecurityError::UnsafeDataAccess {
                        details: format!("Unsafe component name: {}", name),
                    });
                }
                
                for (_, prop_value) in props {
                    self.analyze_expression(prop_value, report, depth + 1)?;
                }
            },
            _ => {} // Other UI elements are considered safe
        }
        
        Ok(())
    }
    
    fn is_safe_component_name(&self, name: &str) -> bool {
        // Component names should be alphanumeric and start with uppercase
        name.chars().next().map_or(false, |c| c.is_uppercase()) &&
        name.chars().all(|c| c.is_alphanumeric() || c == '_')
    }
    
    fn validate_state_access(&self, state_name: &str, report: &mut SecurityReport) -> Result<(), SecurityError> {
        // Check for suspicious state variable names
        let dangerous_names = ["__proto__", "constructor", "prototype", "eval"];
        if dangerous_names.contains(&state_name) {
            return Err(SecurityError::UnsafeDataAccess {
                details: format!("Dangerous state variable name: {}", state_name),
            });
        }
        Ok(())
    }
    
    fn analyze_expression(&self, expr: &Expr, report: &mut SecurityReport, depth: usize) -> Result<(), SecurityError> {
        if depth > self.resource_limits.max_nesting_depth {
            return Err(SecurityError::ResourceLimit {
                resource: "expression nesting depth".to_string(),
                current: depth,
                limit: self.resource_limits.max_nesting_depth,
            });
        }
        
        match expr {
            Expr::FunctionCall { name, args } => {
                // Check if function is blocked
                if self.blocked_functions.contains(name) {
                    return Err(SecurityError::DangerousFunction {
                        function: name.clone(),
                    });
                }
                
                // Analyze arguments
                for arg in args {
                    self.analyze_expression(arg, report, depth + 1)?;
                }
                
                report.function_calls.insert(name.clone());
                
                // Check function call count
                if report.function_calls.len() > self.resource_limits.max_function_calls {
                    return Err(SecurityError::ResourceLimit {
                        resource: "function calls".to_string(),
                        current: report.function_calls.len(),
                        limit: self.resource_limits.max_function_calls,
                    });
                }
            },
            Expr::Variable(name) => {
                report.accessed_state.insert(name.clone());
                self.validate_state_access(name, report)?;
            },
            Expr::String(s) => {
                if s.len() > self.resource_limits.max_string_length {
                    return Err(SecurityError::ResourceLimit {
                        resource: "string length".to_string(),
                        current: s.len(),
                        limit: self.resource_limits.max_string_length,
                    });
                }
                
                // Check for injection attempts
                if s.contains("<script") || s.contains("javascript:") || s.contains("eval(") {
                    return Err(SecurityError::UnsafeDataAccess {
                        details: "Potential code injection in string literal".to_string(),
                    });
                }
            },
            Expr::BinaryOp { left, right, .. } => {
                self.analyze_expression(left, report, depth + 1)?;
                self.analyze_expression(right, report, depth + 1)?;
            },
            Expr::UnaryOp { expr, .. } => {
                self.analyze_expression(expr, report, depth + 1)?;
            },
            Expr::FieldAccess { object, field } => {
                self.analyze_expression(object, report, depth + 1)?;
                
                // Check for dangerous field access
                let dangerous_fields = ["__proto__", "constructor", "prototype"];
                if dangerous_fields.contains(&field.as_str()) {
                    return Err(SecurityError::UnsafeDataAccess {
                        details: format!("Dangerous field access: {}", field),
                    });
                }
            },
            Expr::Interpolation(parts) => {
                for part in parts {
                    if let InterpolatedPart::Expr(expr) = part {
                        self.analyze_expression(expr, report, depth + 1)?;
                    }
                }
            },
            _ => {} // Other expressions are safe
        }
        
        Ok(())
    }
    
    fn analyze_action_code(&self, code: &str, report: &mut SecurityReport) -> Result<(), SecurityError> {
        // Enhanced pattern matching for dangerous code
        let dangerous_patterns = [
            ("eval(", "eval function"),
            ("exec(", "exec function"),
            ("system(", "system call"),
            ("__import__(", "dynamic import"),
            ("open(", "file access"),
            ("file(", "file access"),
            ("fetch(", "network request"),
            ("XMLHttpRequest", "network request"),
            ("document.", "DOM access"),
            ("window.", "global object access"),
            ("location.", "location access"),
            ("setTimeout(", "timer function"),
            ("setInterval(", "timer function"),
        ];
        
        for (pattern, description) in &dangerous_patterns {
            if code.contains(pattern) {
                return Err(SecurityError::DangerousFunction {
                    function: description.to_string(),
                });
            }
        }
        
        // Check for SQL injection patterns
        let sql_patterns = ["DROP ", "DELETE ", "UPDATE ", "INSERT ", "SELECT "];
        for pattern in &sql_patterns {
            if code.to_uppercase().contains(pattern) {
                report.security_warnings.push("Potential SQL injection pattern detected".to_string());
            }
        }
        
        Ok(())
    }
    
    fn calculate_complexity(&self, app: &App) -> usize {
        let mut complexity = 0;
        
        // Base complexity for app structure
        complexity += app.screens.len();
        complexity += app.imports.len() * 2;
        complexity += app.data_models.len() * 3;
        
        // Screen complexity
        for screen in &app.screens {
            complexity += screen.state.len();
            complexity += screen.actions.len() * 2;
            complexity += self.calculate_ui_complexity(&screen.ui);
        }
        
        complexity
    }
    
    fn calculate_ui_complexity(&self, ui: &UI) -> usize {
        match ui {
            UI::Column(children) | UI::Row(children) | UI::Stack(children) => {
                1 + children.iter().map(|child| self.calculate_ui_complexity(child)).sum::<usize>()
            },
            UI::List { child, .. } => 2 + self.calculate_ui_complexity(child),
            UI::Conditional { then_branch, else_branch, .. } => {
                let mut complexity = 3 + self.calculate_ui_complexity(then_branch);
                if let Some(else_branch) = else_branch {
                    complexit
