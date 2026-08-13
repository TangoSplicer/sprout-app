use sprout_compiler::{
    ast::{UiElement, ValueType},
    parser::Parser,
};

fn parse(source: &str) -> Result<sprout_compiler::ast::App, anyhow::Error> {
    Parser::new(source).parse()
}

#[test]
fn parses_state_and_interpolated_ui_elements() {
    let source = r#"
        app "Task List"
        screen Home {
            state count: 2
            ui {
                label "Count: ${count}"
                button "Continue"
            }
        }
    "#;

    let app = parse(source).expect("valid source should parse");
    assert_eq!(app.name, "Task List");
    assert_eq!(app.screens.len(), 1);

    let home = &app.screens[0];
    assert_eq!(home.name, "Home");
    assert_eq!(home.state.len(), 1);
    assert!(matches!(home.state[0].value, ValueType::Number(2)));
    assert!(matches!(
        &home.ui[0],
        UiElement::Label { text } if text == "Count: 2"
    ));
    assert!(matches!(
        &home.ui[1],
        UiElement::Button { label, .. } if label == "Continue"
    ));
}

#[test]
fn rejects_dangerous_expressions_in_state_values() {
    let source = r#"
        app "Unsafe"
        screen Home {
            state command: "eval('untrusted input')"
        }
    "#;

    let error = parse(source).expect_err("dangerous state values must be rejected");
    assert!(error.to_string().contains("Dangerous function"));
}

#[test]
fn rejects_unknown_interpolation_variables() {
    let source = r#"
        app "Unknown variable"
        screen Home {
            ui {
                label "Hello ${name}"
            }
        }
    "#;

    let error = parse(source).expect_err("unknown interpolation must be rejected");
    assert!(error.to_string().contains("Unknown variable"));
}

#[test]
fn rejects_oversized_screen_names() {
    let name = "A".repeat(51);
    let source = format!("app \"Long Screen\"\nscreen {name} {{}}");

    let error = parse(&source).expect_err("oversized screen names must be rejected");
    assert!(error.to_string().contains("Screen name too long"));
}
