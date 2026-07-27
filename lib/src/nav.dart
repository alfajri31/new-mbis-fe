import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'app.dart';

/// Pops the current route, or — when there's nothing to pop (e.g. the browser
/// was refreshed directly onto a detail URL, so this is the only page in the
/// stack) — falls back to the role's home. This keeps the back button from
/// ever being a dead end after a hard reload.
void safePop(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    final isAgent =
        MbisApp.of(context)?.session?.user.roles.contains('AGENT') ?? false;
    context.go(isAgent ? '/agent' : '/dashboard');
  }
}

/// Opens [suffix] (must start with '/') as a sub-route of the current location,
/// so the URL nests (e.g. /customer/123 → /customer/123/pipeline/45) and the
/// back button returns to the current screen. Used for detail-from-detail and
/// detail-from-tab navigation so each screen gets its own refresh-survivable URL
/// — `context.push` is deliberately avoided because go_router omits imperatively
/// pushed routes from the browser URL, so a refresh there would lose the screen.
void goRel(BuildContext context, String suffix) =>
    context.go('${GoRouterState.of(context).matchedLocation}$suffix');
