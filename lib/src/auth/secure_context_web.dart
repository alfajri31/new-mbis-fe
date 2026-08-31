import 'package:web/web.dart' as web;

/// `window.isSecureContext` — true untuk HTTPS, dan juga untuk `localhost`/`127.0.0.1`
/// walau memakai HTTP polos (spesifikasi memperlakukan loopback sebagai tepercaya).
///
/// Itu sekaligus menjelaskan kenapa membuka aplikasi lewat SSH tunnel ke
/// `http://localhost:<port>` menyembuhkan error secure storage tanpa mengubah apa pun
/// di server.
bool isBrowserSecureContext() => web.window.isSecureContext;
