# Custom Collection Draft

- Date: 2026-11-23
- Status: In Review
- Supersedes: None
- Superseded By: None

# Context

A reading plan's book list is the source of truth, and a list that does not
match a preset is shown as Custom. Before this change, the collection
dropdown only offered Custom once the current list already was custom, and
selecting Custom did nothing. That made an empty Custom plan impossible to
start, and switching to a preset discarded the custom list with no way back.

Custom also is not a real preset: `BibleCollections.custom` has id 0 and an
empty book list. It is a sentinel for "none of the presets", so there is no
stored set of books to restore from when the user reselects it.

# Decisions

1. **Custom is always offered in the collection dropdown.** Selecting it
   with no draft yet produces an empty book list. The list can then be built
   with the existing book list editor.
2. **The custom draft lives for the lifetime of the edit view model.**
   `EditReadingPlanViewModel` remembers the last custom list separately from
   the currently selected collection, so switching to one or more presets
   and back restores it. The draft is initialized from the saved books when
   the plan being edited is already custom.
3. **Only the selected list is saved.** If the view model is closed while a
   preset is selected, the retained custom draft is discarded with the view
   model. There is no database, settings, or global persistence for drafts.
4. **A list that exactly matches a preset becomes that preset.** Both
   `setBooks` and collection selection continue to derive the selected
   collection from the ordered book list, using order-sensitive comparison.

# Implementation Notes

- `_customBookIds` is updated only when `setBooks` resolves to Custom, so
  editing into a preset order does not clobber the draft.
- The Custom dropdown entry uses the `BibleCollections.custom` singleton so
  `DropdownButton` identity matching has a single stable value.
- The draft is per-session by design; a new edit session starts from the
  persisted plan.

# Alternatives

- **Persist the draft in the database or settings.** Rejected: the task only
  needs retention while the editor is open, and storing an unselected list
  would need cleanup rules and could resurrect abandoned edits.
- **Store the edit view model outside the panel so it survives closing.**
  Rejected: view models are page-scoped and disposed with their page; keeping
  one alive would leak state and break the ownership rule in the four-layer
  architecture.
- **Add a separate custom collection with a real book list.** Rejected as a
  wider data-model change than needed; the sentinel already represents the
  concept, and the book list remains the source of truth.

# References

- [Four-Layer Architecture](2026-11-18-four-layer-architecture.md)
- [Reactivity Patterns](2026-11-18-reactivity-patterns.md)
