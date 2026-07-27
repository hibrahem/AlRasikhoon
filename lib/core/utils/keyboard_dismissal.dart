import 'package:flutter/material.dart';

/// Closes the soft keyboard when the user taps outside a text field.
///
/// Pass to `TextField.onTapOutside` / `TextFormField.onTapOutside` on EVERY
/// field in the app; `test/widget/form_keyboard_dismiss_test.dart` fails the
/// build if a new one forgets.
///
/// Flutter's default handler drops focus on desktop and web only — for a touch
/// event on Android/iOS it deliberately does nothing, which left the IME's own
/// return key as the sole way out. That stranded users (al_rasikhoon-gvoh):
/// `Scaffold` anchors `bottomNavigationBar` to the viewport bottom and only the
/// body avoids `viewInsets`, so the keyboard covers the nav destinations and
/// they cannot be tapped while it is up.
///
/// Every text field shares one tap region (`TextFieldTapRegion`, grouped under
/// `EditableText`), so moving focus from one field to the next on a form does
/// NOT count as tapping outside — no close-and-reopen flicker. Field chrome
/// such as a clear or reveal button is inside that region too, and keeps focus.
void dismissKeyboardOnTapOutside(PointerDownEvent _) =>
    FocusManager.instance.primaryFocus?.unfocus();
