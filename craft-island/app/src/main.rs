// Tropical Isle launcher.
//
// The demo is a static browser page (index.html + ES modules, no build step).
// This small std-only binary exists so the project's automated check can
// picture the build: it runs the same Playwright capture as the manual
// verification, then exits.
//
//   tropical-isle --screenshot <file.png>   capture the demo and exit
//   tropical-isle                          serve the demo at 127.0.0.1:8801
//                                          (opens the browser when run from
//                                          a terminal)

use std::env;
use std::fs;
use std::io::{IsTerminal, Read, Write};
use std::net::{TcpListener, TcpStream};
use std::path::{Path, PathBuf};
use std::process::{exit, Command};
use std::time::Duration;

/// app/ — the folder that holds this binary's crate (target/{debug,release}/..)
fn app_dir() -> PathBuf {
    env::current_exe()
        .ok()
        .and_then(|p| p.canonicalize().ok())
        .and_then(|p| {
            p.parent() // target/{debug,release}
                .and_then(|pp| pp.parent()) // target
                .and_then(|ppp| ppp.parent()) // app
                .map(|dir| dir.to_path_buf())
        })
        .unwrap_or_else(|| env::current_dir().unwrap_or_else(|_| PathBuf::from(".")))
}

/// Find a usable `node` (the capture script runs with Playwright).
fn find_node() -> Option<PathBuf> {
    // plain PATH lookup first
    if Command::new("node")
        .arg("--version")
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
    {
        return Some(PathBuf::from("node"));
    }
    for base in ["/opt/homebrew/bin/node", "/usr/local/bin/node"] {
        if Path::new(base).is_file() {
            return Some(PathBuf::from(base));
        }
    }
    // nvm-managed installs
    if let Some(home) = env::var_os("HOME") {
        let nvm = Path::new(&home).join(".nvm/versions/node");
        if let Ok(entries) = fs::read_dir(nvm) {
            for entry in entries.flatten() {
                let bin = entry.path().join("bin/node");
                if bin.is_file() {
                    return Some(bin);
                }
            }
        }
    }
    None
}

fn screenshot(out_arg: &str) -> i32 {
    let dir = app_dir();
    // resolve a relative output path against the caller's cwd
    let out = if Path::new(out_arg).is_absolute() {
        PathBuf::from(out_arg)
    } else {
        env::current_dir()
            .unwrap_or_else(|_| dir.clone())
            .join(out_arg)
    };
    let out = out.to_string_lossy().to_string();

    let Some(node) = find_node() else {
        eprintln!("tropical-isle: node is not available, cannot capture");
        return 1;
    };
    let status = Command::new(node)
        .arg("docs/shot.mjs")
        .arg(&out)
        .current_dir(&dir)
        .status();
    match status {
        Ok(s) if s.success() => 0,
        Ok(s) => {
            eprintln!("tropical-isle: capture exited with {s}");
            s.code().unwrap_or(1)
        }
        Err(e) => {
            eprintln!("tropical-isle: capture failed to start: {e}");
            1
        }
    }
}

fn mime_of(path: &str) -> &'static str {
    let ext = Path::new(path).extension().and_then(|e| e.to_str()).unwrap_or("");
    match ext {
        "html" => "text/html; charset=utf-8",
        "js" | "mjs" => "text/javascript; charset=utf-8",
        "css" => "text/css; charset=utf-8",
        "png" => "image/png",
        "jpg" | "jpeg" => "image/jpeg",
        "svg" => "image/svg+xml",
        "json" => "application/json",
        "glb" => "model/gltf-binary",
        "ico" => "image/x-icon",
        _ => "application/octet-stream",
    }
}

fn handle(mut stream: TcpStream, dir: &Path) {
    stream
        .set_read_timeout(Some(Duration::from_secs(10)))
        .ok();
    let mut buf = [0u8; 8192];
    let n = stream.read(&mut buf).unwrap_or(0);
    if n == 0 {
        return;
    }
    let req = String::from_utf8_lossy(&buf[..n]);
    let mut line = req.lines().next().unwrap_or("").split_whitespace();
    let method = line.next().unwrap_or("");
    let target = line.next().unwrap_or("/");
    if method != "GET" && method != "HEAD" {
        write!(stream, "HTTP/1.1 405 Method Not Allowed\r\nContent-Length: 0\r\nConnection: close\r\n\r\n").ok();
        return;
    }
    let path = target.split('?').next().unwrap_or("/");
    let mut rel = if path == "/" {
        "index.html".to_string()
    } else {
        path.trim_start_matches('/').to_string()
    };
    // minimal percent-decoding for the file lookup
    if rel.contains('%') {
        let mut out = String::new();
        let bytes = rel.as_bytes();
        let mut i = 0;
        while i < bytes.len() {
            if bytes[i] == b'%' && i + 2 < bytes.len() {
                if let Ok(v) = u8::from_str_radix(&rel[i + 1..i + 3], 16) {
                    out.push(v as char);
                    i += 3;
                    continue;
                }
            }
            out.push(bytes[i] as char);
            i += 1;
        }
        rel = out;
    }
    if rel.contains("..") {
        write!(stream, "HTTP/1.1 403 Forbidden\r\nContent-Length: 0\r\nConnection: close\r\n\r\n").ok();
        return;
    }
    let full = dir.join(&rel);
    let canon = full.canonicalize().unwrap_or(full);
    let rooted = dir.canonicalize().unwrap_or_else(|_| dir.to_path_buf());
    if !canon.starts_with(&rooted) {
        write!(stream, "HTTP/1.1 403 Forbidden\r\nContent-Length: 0\r\nConnection: close\r\n\r\n").ok();
        return;
    }
    match fs::read(&canon) {
        Ok(body) => {
            let head = format!(
                "HTTP/1.1 200 OK\r\nContent-Type: {}\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
                mime_of(&rel),
                body.len()
            );
            stream.write_all(head.as_bytes()).ok();
            if method == "GET" {
                stream.write_all(&body).ok();
            }
        }
        Err(_) => {
            write!(stream, "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n").ok();
        }
    }
}

fn serve() -> ! {
    let dir = app_dir();
    let listener = TcpListener::bind(("127.0.0.1", 8801))
        .or_else(|_| TcpListener::bind(("127.0.0.1", 0)))
        .expect("cannot bind a port for the demo server");
    let port = listener.local_addr().map(|a| a.port()).unwrap_or(8801);
    println!("Tropical Isle demo at http://127.0.0.1:{port}/ (Ctrl+C to stop)");
    // open the browser only when a person runs it from a terminal; the
    // automated check just needs the server
    if std::io::stdin().is_terminal() {
        let _ = Command::new("open")
            .arg(format!("http://127.0.0.1:{port}/"))
            .spawn();
    }
    loop {
        if let Ok((stream, _)) = listener.accept() {
            handle(stream, &dir);
        }
    }
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if let Some(pos) = args.iter().position(|a| a == "--screenshot") {
        let out = args.get(pos + 1).cloned().unwrap_or_default();
        exit(screenshot(&out));
    }
    serve();
}
