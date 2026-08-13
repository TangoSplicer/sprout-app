use sprout_compiler::parser::Parser;

#[test]
fn ranked_todo_template_parses_as_a_previewable_app() {
    let source = r#"app "Ranked Todo" {
  start = "Todo"
}

screen Todo {
  ui {
    label "My ranked tasks"
    label "1. Plan today"
    label "2. Finish the important task"
    label "3. Review tomorrow"
    button "Add task"
    button "Mark top task complete"
  }
}"#;

    let app = Parser::new(source).parse().expect("template must parse");

    assert_eq!(app.name, "Ranked Todo");
    assert_eq!(app.screens.len(), 1);
    assert_eq!(app.screens[0].name, "Todo");
    assert_eq!(app.screens[0].ui.len(), 6);
}
