use crate::ast::*;
use serde::Serialize;
use std::collections::HashSet;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum SecurityError {
    #[error("Dangerous function call: {function}")]
    DangerousFunction { function: String },
    #[error("Resource limit exceeded: {resource} ({current} > {limit})")]
    ResourceLimit {
        resource: String,
        current: usize,
        limit: usize,
    },
    #[error("Code complexity too high: {complexity}")]
    ComplexityLimit { complexity: usize },
    #[error("Unsafe data access: {details}")]
    UnsafeDataAccess { details: String },
}

pub struct SecurityAnalyzer {
    pub blocked_functions: HashSet<String>,
    pub resource_limits: ResourceLimits,
    pub max_complexity: usize,
}

#[derive(Debug, Clone)]
pub struct ResourceLimits {
    pub max_screens: usize,
    pub max_state_vars: usize,
    pub max_ui_elements: usize,
}

impl Default for ResourceLimits {
    fn default() -> Self {
        Self {
            max_screens: 50,
            max_state_vars: 100,
            max_ui_elements: 500,
        }
    }
}

impl Default for SecurityAnalyzer {
    fn default() -> Self {
        let mut blocked_functions = HashSet::new();
        blocked_functions.insert("eval".to_string());
        blocked_functions.insert("exec".to_string());
        blocked_functions.insert("system".to_string());

        Self {
            blocked_functions,
            resource_limits: ResourceLimits::default(),
            max_complexity: 20,
        }
    }
}

impl SecurityAnalyzer {
    pub fn analyze_app(&self, app: &App) -> Result<SecurityReport, SecurityError> {
        let mut report = SecurityReport::default();

        // Check screen count
        if app.screens.len() > self.resource_limits.max_screens {
            return Err(SecurityError::ResourceLimit {
                resource: "screens".to_string(),
                current: app.screens.len(),
                limit: self.resource_limits.max_screens,
            });
        }

        for screen in &app.screens {
            self.analyze_screen(screen, &mut report)?;
        }

        report.complexity_score = self.calculate_complexity(app);
        report.risk_level = self.calculate_risk_level(&report);

        Ok(report)
    }

    fn analyze_screen(
        &self,
        screen: &Screen,
        report: &mut SecurityReport,
    ) -> Result<(), SecurityError> {
        for ui_element in &screen.ui {
            self.analyze_ui_element(ui_element, report)?;
        }
        Ok(())
    }

    fn analyze_ui_element(
        &self,
        ui: &UiElement,
        report: &mut SecurityReport,
    ) -> Result<(), SecurityError> {
        match ui {
            UiElement::Label { text } => {
                if text.contains("<script") {
                    return Err(SecurityError::UnsafeDataAccess {
                        details: "Script injection detected".to_string(),
                    });
                }
            }
            UiElement::Button { action, .. } => {
                self.analyze_action(action, report)?;
            }
            _ => {}
        }
        Ok(())
    }

    fn analyze_action(
        &self,
        action: &Action,
        report: &mut SecurityReport,
    ) -> Result<(), SecurityError> {
        match action {
            Action::CallFunction { function, .. } => {
                if self.blocked_functions.contains(function) {
                    return Err(SecurityError::DangerousFunction {
                        function: function.clone(),
                    });
                }
                report.function_calls.insert(function.clone());
            }
            Action::If { then, r#else, .. } => {
                self.analyze_action(then, report)?;
                if let Some(else_act) = r#else {
                    self.analyze_action(else_act, report)?;
                }
            }
            Action::Loop { body, .. } => {
                for act in body {
                    self.analyze_action(act, report)?;
                }
            }
            _ => {}
        }
        Ok(())
    }

    fn calculate_complexity(&self, app: &App) -> usize {
        app.screens.len() + app.state.len()
    }

    fn calculate_risk_level(&self, report: &SecurityReport) -> RiskLevel {
        if !report.security_warnings.is_empty() {
            RiskLevel::High
        } else {
            RiskLevel::Low
        }
    }

    pub fn get_risk_level(&self) -> RiskLevel {
        RiskLevel::Low
    }
}

#[derive(Serialize, Debug, Default)]
pub struct SecurityReport {
    pub risk_level: RiskLevel,
    pub complexity_score: usize,
    pub total_ui_elements: usize,
    pub required_permissions: HashSet<String>,
    pub external_resources: HashSet<String>,
    pub navigation_targets: HashSet<String>,
    pub function_calls: HashSet<String>,
    pub security_warnings: Vec<String>,
}

#[derive(Serialize, Debug, PartialEq, Default, Clone)]
pub enum RiskLevel {
    #[default]
    Low,
    Medium,
    High,
    Critical,
}
