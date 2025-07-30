// rust/sprout_compiler/src/ast.rs
/// The full Abstract Syntax Tree for SproutScript
///
/// Designed for:
/// - Simplicity: easy to parse and understand
/// - Power: supports data, imports, and rich UI
/// - Extensibility: ready for future features

#[derive(Debug, Clone)]
pub struct App {
    pub name: String,
    pub icon: Option<String>,
    pub theme: AppTheme,
    pub start_screen: String,
    pub imports: Vec<Import>,
    pub data_models: Vec<DataModel>,
    pub screens: Vec<Screen>,
}

#[derive(Debug, Clone)]
pub struct Import {
    pub name: String,           // e.g., "ui", "http"
    pub path: String,           // e.g., "@sprout/ui", "github.com/user/lib"
}

#[derive(Debug, Clone)]
pub struct DataModel {
    pub name: String,
    pub fields: Vec<DataField>,
}

#[derive(Debug, Clone)]
pub struct DataField {
    pub name: String,
    pub type_name: DataType,
    pub default: Option<Expr>,
}

#[derive(Debug, Clone)]
pub enum DataType {
    String,
    Int,
    Float,
    Boolean,
    Date,
    List(Box<DataType>),
    Custom(String), // e.g., Task, User
}

#[derive(Debug, Clone)]
pub struct Screen {
    pub name: String,
    pub parameters: Vec<Parameter>,
    pub state: Vec<StateDecl>,
    pub ui: UI,
    pub actions: Vec<Action>,
}

#[derive(Debug, Clone)]
pub struct Parameter {
    pub name: String,
    pub type_name: String, // Passed-in data type
}

#[derive(Debug, Clone)]
pub struct StateDecl {
    pub name: String,
    pub value: Expr,
}

#[derive(Debug, Clone)]
pub enum UI {
    Column(Vec<UI>),
    Row(Vec<UI>),
    Stack(Vec<UI>),
    Label(String),
    Title(String),
    Button {
        label: String,
        action: Option<String>,
        navigate: Option<Navigation>,
    },
    Image { src: String },
    Input {
        label: String,
        binding: String, // state variable
    },
    List {
        items: String, // state list name
        child: Box<UI>,
    },
    Conditional {
        condition: Expr,
        then_branch: Box<UI>,
        else_branch: Option<Box<UI>>,
    },
    Binding {
        variable: String,
        child: Box<UI>,
    },
    CustomComponent {
        name: String,
        props: Vec<(String, Expr)>,
    },
}

#[derive(Debug, Clone)]
pub struct Navigation {
    pub screen: String,
    pub args: Vec<Expr>, // passed to next screen
}

#[derive(Debug, Clone)]
pub struct Action {
    pub code: String, // raw code block
}

#[derive(Debug, Clone)]
pub enum Expr {
    Number(f64),
    String(String),
    Boolean(bool),
    Variable(String),
    UnaryOp { op: String, expr: Box<Expr> },
    BinaryOp { op: String, left: Box<Expr>, right: Box<Expr> },
    FieldAccess { object: Box<Expr>, field: String },
    FunctionCall { name: String, args: Vec<Expr> },
    Interpolation(Vec<InterpolatedPart>), // for "${count} items"
}

#[derive(Debug, Clone)]
pub enum InterpolatedPart {
    Text(String),
    Expr(Expr),
}

// Themes
#[derive(Debug, Clone)]
pub enum AppTheme {
    Light,
    Dark,
    Custom { primary: String, background: String },
}

// Helper constructors for easier testing
impl App {
    pub fn new(name: &str, start: &str) -> Self {
        App {
            name: name.to_string(),
            icon: None,
            theme: AppTheme::Light,
            start_screen: start.to_string(),
            imports: vec![],
            data_models: vec![],
            screens: vec![],
        }
    }
}

impl DataModel {
    pub fn new(name: &str) -> Self {
        DataModel {
            name: name.to_string(),
            fields: vec![],
        }
    }
}

impl DataField {
    pub fn string(name: &str) -> Self {
        DataField {
            name: name.to_string(),
            type_name: DataType::String,
            default: None,
        }
    }

    pub fn int(name: &str) -> Self {
        DataField {
            name: name.to_string(),
            type_name: DataType::Int,
            default: None,
        }
    }

    pub fn boolean(name: &str) -> Self {
        DataField {
            name: name.to_string(),
            type_name: DataType::Boolean,
            default: Some(Expr::Boolean(false)),
        }
    }
}

impl Screen {
    pub fn new(name: &str) -> Self {
        Screen {
            name: name.to_string(),
            parameters: vec![],
            state: vec![],
            ui: UI::Column(vec![]),
            actions: vec![],
        }
    }
}

impl StateDecl {
    pub fn new(name: &str, value: Expr) -> Self {
        StateDecl {
            name: name.to_string(),
            value,
        }
    }
}

impl Expr {
    pub fn var(name: &str) -> Self {
        Expr::Variable(name.to_string())
    }

    pub fn str(s: &str) -> Self {
        Expr::String(s.to_string())
    }

    pub fn num(n: f64) -> Self {
        Expr::Number(n)
    }
}