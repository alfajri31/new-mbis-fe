/// Native platforms never call this (callers gate on `kIsWeb` first); always false.
bool isMobileBrowserUserAgent() => false;
