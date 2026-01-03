// GENERATED CODE - DO NOT MODIFY BY HAND
// FFI Bridge for Sprout Compiler

use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_int};
use std::ptr;

use crate::{compile_with_security, validate_source_code, SecurityLevel, CompileOptions};

/// # Safety
/// This function is FFI-safe
#[no_mangle]
pub unsafe extern "C" fn compile_sprout_script(source: *const c_char) -> *mut c_char {
    if source.is_null() {
        return CString::new("{&quot;error&quot;:&quot;Source code is null&quot;}").unwrap().into_raw();
    }

    let source_str = match CStr::from_ptr(source).to_str() {
        Ok(s) => s,
        Err(_) => return CString::new("{&quot;error&quot;:&quot;Invalid UTF-8&quot;}").unwrap().into_raw(),
    };

    let options = CompileOptions::default();
    let security_level = SecurityLevel::Strict;

    match compile_with_security(source_str, &options, &security_level) {
        Ok(result) => {
            let json = serde_json::to_string(&result).unwrap_or_else(|_| "{&quot;error&quot;:&quot;Serialization failed&quot;}".to_string());
            CString::new(json).unwrap().into_raw()
        }
        Err(e) => {
            let error_json = format!(r#"{{"error":"{}"}}"#, e);
            CString::new(error_json).unwrap().into_raw()
        }
    }
}

/// # Safety
/// This function is FFI-safe
#[no_mangle]
pub unsafe extern "C" fn parse_sprout_script(source: *const c_char) -> *mut c_char {
    if source.is.null() {
        return CString::new("{&quot;error&quot;:&quot;Source code is null&quot;}").unwrap().into_raw();
    }

    let source_str = match CStr::from_ptr(source).to_str() {
        Ok(s) => s,
        Err(_) => return CString::new("{&quot;error&quot;:&quot;Invalid UTF-8&quot;}").unwrap().into_raw(),
    };

    match crate::parser::parse_sproutscript(source_str) {
        Ok(ast) => {
            let json = serde_json::to_string(&ast).unwrap_or_else(|_| "{&quot;error&quot;:&quot;Serialization failed&quot;}".to_string());
            CString::new(json).unwrap().into_raw()
        }
        Err(e) => {
            let error_json = format!(r#"{{"error":"{}"}}"#, e);
            CString::new(error_json).unwrap().into_raw()
        }
    }
}

/// # Safety
/// This function is FFI-safe
#[no_mangle]
pub unsafe extern "C" fn validate_code(source: *const c_char) -> c_int {
    if source.is_null() {
        return 0;
    }

    let source_str = match CStr::from_ptr(source).to_str() {
        Ok(s) => s,
        Err(_) => return 0,
    };

    match validate_source_code(source_str, &SecurityLevel::Strict) {
        Ok(_) => 1,
        Err(_) => 0,
    }
}

/// # Safety
/// This function is FFI-safe
#[no_mangle]
pub unsafe extern "C" fn get_last_error() -> *mut c_char {
    // In a real implementation, you'd store the last error globally
    // For now, return an empty error message
    CString::new("").unwrap().into_raw()
}

/// # Safety
/// This function is FFI-safe
#[no_mangle]
pub unsafe extern "C" fn get_version() -> *mut c_char {
    let version = env!("CARGO_PKG_VERSION");
    CString::new(version).unwrap().into_raw()
}

/// # Safety
/// This function is FFI-safe - must be called to free strings returned by other functions
#[no_mangle]
pub unsafe extern "C" fn free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        let _ = CString::from_raw(ptr);
    }
}