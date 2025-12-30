use sprout_compiler::*;

#[cfg(test)]
mod integration_tests {
    use super::*;

    #[test]
    fn test_complete_app_compilation() {
        let source = r#"
            app "TodoApp" {
                start = "Home"
            }
            
            screen Home {
                state todos = []
                state newTodo = ""
                
                ui {
                    column {
                        title "Todo List"
                        
                        input "New Todo" binding: newTodo
                        
                        button "Add" {
                            todos.push(newTodo)
                            newTodo = ""
                        }
                        
                        list todos {
                            row {
                                label "${item.text}"
                                button "Delete" {
                                    todos.remove(item)
                                }
                            }
                        }
                    }
                }
            }
        "#;
        
        let result = compile_with_security(source, &CompileOptions::default(), &SecurityLevel::Strict);
        assert!(result.is_ok());
        
        let compile_result = result.unwrap();
        assert!(compile_result.success);
        assert!(!compile_result.wasm.is_empty());
        assert_eq!(compile_result.security_report.risk_level, RiskLevel::Low);
    }

    #[test]
    fn test_security_violations() {
        let malicious_source = r#"
            app "BadApp" {
                start = "Home"
            }
            
            screen Home {
                ui {
                    button "Evil" {
                        eval("alert('hacked')")
                    }
                }
            }
        "#;
        
        let result = compile_with_security(malicious_source, &CompileOptions::default(), &SecurityLevel::Strict);
        assert!(result.is_ok());
        
        let compile_result = result.unwrap();
        assert!(!compile_result.success);
        assert!(compile_result.errors.iter().any(|e| e.contains("eval")));
    }

    #[test]
    fn test_performance_benchmark() {
        let source = r#"
            app "SimpleApp" {
                start = "Home"
            }
            
            screen Home {
                ui {
                    label "Hello World"
                }
            }
        "#;
        
        let benchmark_result = benchmark_compilation(source.to_string(), 10);
        let stats: serde_json::Value = serde_json::from_str(&benchmark_result).unwrap();
        
        assert_eq!(stats["iterations"], 10);
        assert!(stats["average_ms"].as_u64().unwrap() > 0);
        assert!(stats["source_size"].as_u64().unwrap() > 0);
    }

    #[test]
    fn test_compiler_info() {
        let info = get_compiler_info();
        let json: serde_json::Value = serde_json::from_str(&info).unwrap();
        
        assert_eq!(json["name"], "sprout_compiler");
        assert!(json["version"].is_string());
        assert!(json["features"].is_array());
        assert_eq!(json["security_level"], "strict");
    }

    #[test]
    fn test_complex_ui_structures() {
        let source = r#"
            app "ComplexApp" {
                start = "Home"
            }
            
            screen Home {
                state showDetails = false
                state count = 0
                
                ui {
                    column {
                        title "Complex UI Demo"
                        
                        row {
                            button "Toggle Details" {
                                showDetails = !showDetails
                            }
                            
                            button "Increment" {
                                count = count + 1
                            }
                        }
                        
                        if showDetails {
                            column {
                                label "Details Section"
                                label "Count: ${count}"
                                
                                if count > 5 {
                                    label "High count!"
                                } else {
                                    label "Low count"
                                }
                            }
                        }
                    }
                }
            }
        "#;
        
        let result = compile_with_security(source, &CompileOptions::default(), &SecurityLevel::Moderate);
        assert!(result.is_ok());
        
        let compile_result = result.unwrap();
        assert!(compile_result.success);
        assert!(compile_result.metadata.size > 0);
        assert!(!compile_result.metadata.entry_points.is_empty());
    }

    #[test]
    fn test_data_models() {
        let source = r#"
            app "DataApp" {
                start = "Home"
            }
            
            data Todo {
                id: Int = 0
                text: String = ""
                completed: Boolean = false
            }
            
            screen Home {
                state todos = []
                
                ui {
                    column {
                        title "Todos"
                        
                        list todos {
                            row {
                                label "${item.text}"
                                if item.completed {
                                    label "✓"
                                }
                            }
                        }
                    }
                }
            }
        "#;
        
        let result = compile_with_security(source, &CompileOptions::default(), &SecurityLevel::Strict);
        assert!(result.is_ok());
        
        let compile_result = result.unwrap();
        assert!(compile_result.success);
    }

    #[test]
    fn test_navigation() {
        let source = r#"
            app "NavApp" {
                start = "Home"
            }
            
            screen Home {
                ui {
                    column {
                        title "Home"
                        button "Go to Settings" {
                            -> Settings
                        }
                        button "Go to Profile" {
                            -> Profile("user123")
                        }
                    }
                }
            }
            
            screen Settings {
                ui {
                    column {
                        title "Settings"
                        button "Back" {
                            -> Home
                        }
                    }
                }
            }
            
            screen Profile(userId: String) {
                ui {
                    column {
                        title "Profile: ${userId}"
                        button "Back" {
                            -> Home
                        }
                    }
                }
            }
        "#;
        
        let result = compile_with_security(source, &CompileOptions::default(), &SecurityLevel::Strict);
        assert!(result.is_ok());
        
        let compile_result = result.unwrap();
        assert!(compile_result.success);
        assert_eq!(compile_result.metadata.entry_points.len(), 3);
        assert!(compile_result.metadata.entry_points.contains(&"Home".to_string()));
        assert!(compile_result.metadata.entry_points.contains(&"Settings".to_string()));
        assert!(compile_result.metadata.entry_points.contains(&"Profile".to_string()));
    }
}
