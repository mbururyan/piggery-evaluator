import 'package:flutter/material.dart';

/// The Piggery Evaluator palette. Every colour in the app comes from here.
///
/// The one rule that matters: brand red is NEVER a status colour.
/// Problems are [alert] (burnt orange) and always carry a word on the pill,
/// so "red" on screen only ever means "this is FCL / this is the main action".
class AppColors {
  AppColors._();

  // ── Brand ────────────────────────────────────────────────────────────────
  // Placeholder until FCL supplies its exact brand hex. Swap this one line.
  static const red = Color(0xFFC8102E);
  static const redDark = Color(0xFF9E0B23); // pressed states, text on redTint
  static const redTint = Color(0xFFFCEBEE); // nav indicator, "ready next" chips

  // ── Surfaces & text ──────────────────────────────────────────────────────
  static const white = Color(0xFFFFFFFF); // cards, sheets, inputs
  static const page = Color(0xFFF7F5F2); // background behind cards
  static const ink = Color(0xFF1E1E1E); // body text; web sidebar
  static const muted = Color(0xFF6B6B6B); // secondary text
  static const line = Color(0xFFE4E0DB); // borders, dividers

  // ── Status ───────────────────────────────────────────────────────────────
  static const green = Color(0xFF1F7A3D); // synced, okay, meets
  static const greenTint = Color(0xFFE6F2EA);

  static const amber = Color(0xFFD98A12); // pending sync, drafts, approaching
  static const amberTint = Color(0xFFFBF1E0);
  // Amber itself is too light to read as text on its tint; use this instead.
  static const amberText = Color(0xFF8A560A);

  static const alert = Color(0xFFC2410C); // no, needs attention, below, errors
  static const alertTint = Color(0xFFFCEDE5);
}