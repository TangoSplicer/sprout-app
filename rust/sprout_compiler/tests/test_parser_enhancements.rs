// Tests for enhanced parser with line tracking

#[cfg(test)]
mod parser_enhancement_tests {
    use sprout_compiler::parser;

    #[test]
    fn test_string_literal_preservation() {
        // Test that strings with spaces are preserved
        let source = r#"
        app "My App" {
            start = Home
        }
        
        screen Home {
            state message = "Hello World"
            ui {
                label "This is a test"
            }
        }
        "#;

        let result = parser::parse(source);
        assert!(result.is_ok(), "Should parse successfully");
        
        let app = result.unwrap();
        assert_eq!(app.name, "My App");
        
        // Check screen state
        let home_screen = app.screens.iter().find(|s| s.name == "Home").unwrap();
        assert_eq!(home_screen.state.len(), 1);
        assert_eq!(home_screen.state[0].name, "message");
        
        // Check label content
        if let crate::ast::UI::Column(children) = &home_screen.ui {
            if let crate::ast::UI::Label(text) = &children[0] {
                assert_eq!(text, "This is a test");
            } else {
                panic!("Expected label");
            }
        } else {
            panic!("Expected column");
        }
    }

    #[test]
    fn test_multiline_strings() {
        // Test handling of multiline strings
        let source = r#"
        app "Test App" {
            start = Home
        }
        
        screen Home {
            ui {
                label "Line 1
Line 2
Line 3"
            }
        }
        "#;

        let result = parser::parse(source);
        assert!(result.is_ok(), "Should parse multiline strings");
    }

    #[test]
    fn test_nested_containers() {
        // Test deeply nested UI structures
        let source = r#"
        app "Test App" {
            start = Home
        }
        
        screen Home {
            ui {
                column {
                    row {
                        label "Inner 1"
                        button "Click" { }
                    }
                    column {
                        label "Inner 2"
                        label "Inner 3"
                    }
                }
            }
        }
        "#;

        let result = parser::parse(source);
        assert!(result.is_ok(), "Should parse nested containers");
        
        let app = result.unwrap();
        let home_screen = &app.screens[0];
        
        // Verify structure
        if let crate::ast::UI::Column(level1) = &home_screen.ui {
            assert_eq!(level1.len(), 2); // row and column
            
            if let crate::ast::UI::Row(level2) = &level1[0] {
                assert_eq!(level2.len(), 2); // label and button
            }
        }
    }

    #[test]
    fn test_complex_expressions() {
        // Test function calls and expressions
        let source = r#"
        app "Test App" {
            start = Home
        }
        
        screen Home {
            state count = 0
            state total = add(count, 10)
            
            ui {
                label "${count} items"
                button "Add 5" {
                    count = count + 5
                }
            }
        }
        "#;

        let result = parser::parse(source);
        assert!(result.is_ok(), "Should parse complex expressions");
        
        let app = result.unwrap();
        let home_screen = &app.screens[0];
        
        assert_eq!(home_screen.state.len(), 2);
        assert_eq!(home_screen.state[0].name, "count");
        assert_eq!(home_screen.state[1].name, "total");
    }

    #[test]
    fn test_conditional_ui() {
        // Test if/else conditional UI
        let source = r#"
        app "Test App" {
            start = Home
        }
        
        screen Home {
            state is_logged_in = true
            
            ui {
                if is_logged_in {
                    label "Welcome back!"
                } else {
                    label "Please login"
                }
            }
        }
        "#;

        let result = parser::parse(source);
        assert!(result.is_ok(), "Should parse conditional UI");
        
        let app = result.unwrap();
        let home_screen = &app.screens[0];
        
        if let crate::ast::UI::Conditional { then_branch, else_branch, .. } = &home_screen.ui {
            assert!(then_branch.is_some());
            assert!(else_branch.is_some());
        } else {
            panic!("Expected conditional UI");
        }
    }

    #[test]
    fn test_navigation_with_args() {
        // Test screen navigation with arguments
        let source = r#"
        app "Test App" {
            start = Home
        }
        
        screen Home {
            ui {
                button "Go to Details" {
                    -> DetailPage(42, "test")
                }
            }
        }
        
        screen DetailPage(id: Int, name: String) {
            ui {
                label "${id}"
                label name
            }
        }
        "#;

        let result = parser::parse(source);
        assert!(result.is_ok(), "Should parse navigation with arguments");
        
        let app = result.unwrap();
        
        // Check DetailPage has parameters
        let detail_screen = app.screens.iter().find(|s| s.name == "DetailPage").unwrap();
        assert_eq!(detail_screen.parameters.len(), 2);
        assert_eq!(detail_screen.parameters[0].name, "id");
        assert_eq!(detail_screen.parameters[1].name, "name");
    }

    #[test]
    fn test_data_model_with_defaults() {
        // Test data models with default values
        let source = r#"
        app "Test App" {
            start = Home
        }
        
        data Task {
            title: String
            done: Boolean = false
            priority: Int = 5
        }
        
        screen Home {
            ui {
                label "Task App"
            }
        }
        "#;

        let result = parser::parse(source);
        assert!(result.is_ok(), "Should parse data models with defaults");
        
        let app = result.unwrap();
        assert_eq!(app.data_models.len(), 1);
        
        let task_model = &app.data_models[0];
        assert_eq!(task_model.name, "Task");
        assert_eq!(task_model.fields.len(), 3);
        
        // Check default values
        let done_field = &task_model.fields[1];
        assert!(done_field.default.is_some());
        
        let priority_field = &task_model.fields[2];
        assert!(priority_field.default.is_some());
    }

    #[test]
    fn test_list_widget() {
        // Test list widget rendering
        let source = r#"
        app "Test App" {
            start = Home
        }
        
        screen Home {
            state items = []
            
            ui {
                list items {
                    label "${item}"
                }
            }
        }
        "#;

        let result = parser::parse(source);
        assert!(result.is_ok(), "Should parse list widget");
        
        let app = result.unwrap();
        let home_screen = &app.screens[0];
        
        if let crate::ast::UI::List { items, child } = &home_screen.ui {
            assert_eq!(items, "items");
            assert!(child.is_some());
        } else {
            panic!("Expected list UI");
        }
    }
}