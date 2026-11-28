# View Initialization and Navigation

- Date: 2026-11-27
- Status: In Review
- Supersedes: None
- Superseded By: None

# Context

Every reading-plan page hand-rolled the same navigation sequence: resolve the
messenger, await a view model's `create`, catch and localize an error, check
`context.mounted`, push a route or sheet, and dispose the view model when the
push never happened. The copies drifted, and ownership was ambiguous: the
route entry point and the page state could both think they disposed the same
view model.

# Decisions

- View models keep the `static Future<VM> create({...})` convention.
  Shared dependencies are `final` fields initialized from getIt at the top
  of the view model per [Single-Constructor Dependency
  Resolution](2026-11-27-single-constructor-resolution.md). The factory
  takes instance data, initializes the view model, and a failure disposes it
  before rethrowing.
- `pushInitializedPage` and `pushViewModelPage` own the shared sequence:
  create, error message, mounted check, presentation, and disposal of an
  abandoned value. They replace per-page `navigateTo` bodies.
- Create-before-push is for fast, one-shot, local initialization. Slow,
  retryable, or progressive initialization belongs in a view model or an
  in-page loading state, not in a blank route the user waits on.
- No shared ownership widget is introduced. After a successful presentation,
  the page's `State` is the sole disposer. The sanctioned split is: the route
  entry creates, the page's `State` disposes, and the navigation helper
  disposes only when navigation is abandoned.
- Use `navigateTo` for routes and `show` for sheets and dialogs. Sheets supply
  a `present` callback so they keep their presentation options while the
  helper still owns creation and abandonment.

# Implementation Notes

- `lib/ui/navigation/view_model_navigation.dart` contains
  `pushInitializedPage<T, R>` and `pushViewModelPage<VM extends ChangeNotifier,
  R>`. Both stay free of slice imports.
- Initialization errors show `errorLoadingContent` unless a caller supplies
  `loadErrorMessage`. The error is shown only while the calling context is
  still mounted.
- An initialized value is disposed when the calling context unmounted before
  presentation, or when presentation throws. After a successful presentation,
  only the page's `State` disposes it; callers must not add a second disposer.
- The helpers resolve `MessengerViewModel` from getIt up front, following the
  single-constructor rule for static factories. They are one-shot functions
  and hold no state; there is no long-lived navigation service.

# Alternatives

- **Keep per-page navigation boilerplate.** Rejected: the duplicate sequences
  drifted and made ownership unverifiable.
- **A shared `ViewModelView` ownership widget.** Rejected: it exists only to
  avoid a page `State` retaining the view model, and a stateful page may have
  other legitimate local concerns. The page's own `State` disposes the view
  model it receives.
- **Create the view model inside the page widget.** Rejected for the current
  pages: they need a local `create` that can fail before a route exists, and
  the entry point already has the context for the localized error.
- **A global `NavigationService`.** Rejected: it adds long-lived state and
  indirection for a sequence that is local to each navigation.
- **InheritedWidget/Provider ownership scope.** Rejected: pages receive their
  view model through constructors and need no ambient scope.

# References

- [Architecture: View initialization and navigation](../ARCHITECTURE.md)
- [Single-Constructor Dependency Resolution](2026-11-27-single-constructor-resolution.md)
- [Four-Layer Architecture](2026-11-18-four-layer-architecture.md)
