// rust/sprout_compiler/src/generator.rs
use crate::ast::*;
use std::collections::HashMap;

pub struct NativeAppGenerator {
    pub app: App,
    pub project_name: String,
}

impl NativeAppGenerator {
    pub fn new(app: App, project_name: &str) -> Self {
        Self {
            app,
            project_name: project_name.to_string(),
        }
    }

    pub fn generate_android(&self) -> HashMap<String, String> {
        let mut files = HashMap::new();

        // AndroidManifest.xml
        files.insert(
            "AndroidManifest.xml".to_string(),
            self.generate_manifest(),
        );

        // MainActivity.kt
        files.insert(
            "MainActivity.kt".to_string(),
            self.generate_kotlin(),
        );

        // layout/activity_main.xml
        files.insert(
            "res/layout/activity_main.xml".to_string(),
            self.generate_layout(),
        );

        // strings.xml
        files.insert(
            "res/values/strings.xml".to_string(),
            format!(r#"<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">{}</string>
</resources>"#, self.app.name),
        );

        // styles.xml
        files.insert(
            "res/values/styles.xml".to_string(),
            r#"<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="AppTheme" parent="Theme.AppCompat.Light.NoActionBar">
        <item name="colorPrimary">#4A9D5E</item>
        <item name="colorPrimaryDark">#3d844c</item>
        <item name="colorAccent">#FFC107</item>
    </style>
</resources>"#.to_string(),
        );

        files
    }

    fn generate_manifest(&self) -> String {
        format!(r#"<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="garden.sprout.{}">
    <application
        android:label="@string/app_name"
        android:theme="@style/AppTheme">
        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
    </application>
</manifest>"#, self.project_name.replace("-", "_"))
    }

    fn generate_kotlin(&self) -> String {
        let mut state_decls = String::new();
        let mut init_code = String::new();
        let mut click_handlers = String::new();

        for screen in &self.app.screens {
            for state in &screen.state {
                let val = match &state.value {
                    Expr::Number(n) => n.to_string(),
                    Expr::String(s) => format!("\"{}\"", s),
                    Expr::Boolean(b) => b.to_string(),
                    _ => "null".to_string(),
                };
                state_decls.push_str(&format("    private var {} = {}\n", state.name, val));
            }

            // onLaunch
            for action in &screen.actions {
                if action.code.contains("onLaunch") {
                    let code = action.code.replace("onLaunch", "").replace("{", "").replace("}", "").trim();
                    init_code.push_str(&format("        // onLaunch\n        {}\n", code));
                }
            }

            // Button handlers
            click_handlers.push_str(&format!("    private fun setup{}Buttons() {{\n", screen.name));
            click_handlers.push_str("        // Generated click handlers\n");
            click_handlers.push_str("    }\n\n");
        }

        format!(r#"package garden.sprout.{}

import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity

class MainActivity : AppCompatActivity() {{
{state_decls}
    override fun onCreate(savedInstanceState: Bundle?) {{
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

{init_code}
        setupHomeButtons()
    }}
}}
"#, self.project_name.replace("-", "_"), state_decls = state_decls, init_code = init_code)
    }

    fn generate_layout(&self) -> String {
        // MVP: generate a simple linear layout
        let mut children = String::new();

        if let Some(home) = self.app.screens.iter().find(|s| s.name == "Home") {
            match &home.ui {
                UI::Column(items) => {
                    for item in items {
                        match item {
                            UI::Label(text) => {
                                children.push_str(&format!(r#"        <TextView
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:text="{}"
            android:layout_margin="8dp" />
"#, text));
                            }
                            UI::Button {{ label, .. }} => {
                                children.push_str(&format!(r#"        <Button
            android:id="@+id/btn_{label}"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:text="{label}"
            android:layout_margin="8dp" />
"#));
                            }
                            _ => {}
                        }
                    }
                }
                _ => {}
            }
        }

        format!(r#"<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:gravity="center"
    android:padding="16dp">

{children}
</LinearLayout>"#, children = children)
    }
}