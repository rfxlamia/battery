/**
 * Battery GNOME Shell Extension
 *
 * Thin shell integration layer. All logic lives in lib/.
 * Reads ~/.battery/state.json via Gio and renders a top-bar indicator.
 */
import Clutter from 'gi://Clutter';
import GLib from 'gi://GLib';
import Gio from 'gi://Gio';
import GObject from 'gi://GObject';
import St from 'gi://St';
import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';

import { getIndicatorLabel } from './lib/status-model.js';
import { parseStateJson } from './lib/state-reader.js';
import { buildPopupRows, utilizationColorLevel } from './lib/popup-view.js';
import { getLocalStateStatusForReadFailure } from './lib/read-error-status.js';
import { getBatteryCoreLoginCommand } from './lib/core-launcher.js';

const REFRESH_INTERVAL_SECONDS = 30;

export default class BatteryExtension extends Extension {
  enable() {
    this._indicator = new BatteryIndicator(this);
    Main.panel.addToStatusArea(this.uuid, this._indicator);
  }

  disable() {
    this._indicator?.destroy();
    this._indicator = null;
  }
}

const BatteryIndicator = GObject.registerClass(class BatteryIndicator extends PanelMenu.Button {
  _init(extension) {
    super._init(0.0, 'Battery');

    this._extension = extension;
    this._stateFile = GLib.get_home_dir() + '/.battery/state.json';

    this._label = new St.Label({
      text: 'Battery …',
      style_class: 'battery-label',
      y_align: Clutter.ActorAlign.CENTER,
    });
    this.add_child(this._label);

    this._refresh();
    this._timerId = GLib.timeout_add_seconds(
      GLib.PRIORITY_DEFAULT,
      REFRESH_INTERVAL_SECONDS,
      () => {
        this._refresh();
        return GLib.SOURCE_CONTINUE;
      },
    );
  }

  _readState() {
    try {
      const file = Gio.File.new_for_path(this._stateFile);
      const [ok, contents] = file.load_contents(null);
      if (!ok) {
        return { _localStateStatus: getLocalStateStatusForReadFailure({ ok: false, gioApi: Gio }) };
      }
      const rawJson = new TextDecoder().decode(contents);
      return parseStateJson(rawJson) ?? { _localStateStatus: 'invalid' };
    } catch (error) {
      return { _localStateStatus: getLocalStateStatusForReadFailure({ error, gioApi: Gio }) };
    }
  }

  _refresh() {
    const state = this._readState();
    this._label.set_text(getIndicatorLabel(state));
    this.menu.removeAll();
    _buildPopupContent(this.menu, state);
    if (state?.status === 'login_required') {
      this.menu.addAction('Sign in', () => {
        try {
          const cmd = getBatteryCoreLoginCommand(GLib.get_home_dir());
          const proc = Gio.Subprocess.new(cmd, Gio.SubprocessFlags.NONE);
          proc.init(null);
          // Login is async — the 30-second poll timer will pick up ok state
          // when the browser OAuth flow completes.
        } catch (err) {
          console.error('Battery: failed to launch login command:', err);
        }
      });
    }
    this.menu.addAction('Reload state', () => this._refresh());
  }

  destroy() {
    if (this._timerId) {
      GLib.source_remove(this._timerId);
      this._timerId = null;
    }
    super.destroy();
  }
});

/**
 * Populate a PanelMenu.Menu with styled items derived from state rows.
 *
 * Progress rows get a Cairo-drawn gauge bar + colored value label.
 * Key/value rows get a two-column label/value layout.
 *
 * @param {object} menu - PanelMenu.Menu instance
 * @param {object|null} state
 */
function _buildPopupContent(menu, state) {
  const rows = buildPopupRows(state);

  for (const row of rows) {
    if (row.message != null) {
      const item = new PopupMenu.PopupMenuItem(row.message);
      if (row.stale || row.loginRequired) item.label.style_class = 'battery-stale-notice';
      else if (row.error) item.label.style_class = 'battery-error-notice';
      item.sensitive = false;
      menu.addMenuItem(item);
    } else if (row.isProgressRow) {
      menu.addMenuItem(_makeProgressRow(row));
    } else if (row.label != null) {
      menu.addMenuItem(_makeKeyValueRow(row));
    }
  }
}

/**
 * Two-column key/value row: dimmed label on left, bold value on right.
 */
function _makeKeyValueRow(row) {
  const item = new PopupMenu.PopupBaseMenuItem({ reactive: false });
  item.add_child(new St.Label({
    text: row.label,
    style_class: 'battery-row-label',
    x_expand: true,
  }));
  item.add_child(new St.Label({
    text: row.value,
    style_class: 'battery-row-value',
  }));
  return item;
}

/**
 * Progress gauge row: label + colored % on top, Cairo progress bar below.
 */
function _makeProgressRow(row) {
  const item = new PopupMenu.PopupBaseMenuItem({ reactive: false });

  const box = new St.BoxLayout({
    vertical: true,
    style_class: 'battery-progress-row',
    x_expand: true,
  });

  // Header: label left, colored value right
  const header = new St.BoxLayout({ x_expand: true });
  header.add_child(new St.Label({
    text: row.label,
    style_class: 'battery-row-label',
    x_expand: true,
  }));
  header.add_child(new St.Label({
    text: row.value,
    style_class: `battery-row-value battery-value-${row.colorLevel}`,
  }));
  box.add_child(header);

  // Cairo-drawn progress bar
  box.add_child(_makeProgressBar(row.utilization, row.colorLevel));

  item.add_child(box);
  return item;
}

/**
 * Creates a Cairo-drawn horizontal progress bar as St.DrawingArea.
 *
 * @param {number} utilization - 0.0 to 1.0
 * @param {'green'|'yellow'|'orange'|'red'} colorLevel
 * @returns {St.DrawingArea}
 */
function _makeProgressBar(utilization, colorLevel) {
  const area = new St.DrawingArea({
    style_class: 'battery-gauge-area',
    x_expand: true,
  });

  area.connect('repaint', (widget) => {
    const cr = widget.get_context();
    const [w, h] = widget.get_surface_size();
    if (w === 0 || h === 0) {
      cr.$dispose();
      return;
    }

    const r = h / 2;

    // Track background
    cr.setSourceRGBA(1, 1, 1, 0.12);
    _drawRoundedRect(cr, 0, 0, w, h, r);
    cr.fill();

    // Filled portion (at least a full-radius pill if any utilization)
    const clamped = Math.min(Math.max(utilization, 0), 1);
    if (clamped > 0) {
      const fillWidth = Math.max(2 * r, w * clamped);
      const [fr, fg, fb] = _rgbForLevel(colorLevel);
      cr.setSourceRGBA(fr, fg, fb, 0.9);
      _drawRoundedRect(cr, 0, 0, fillWidth, h, r);
      cr.fill();
    }

    cr.$dispose();
  });

  return area;
}

/**
 * Draws a rounded rectangle path on a Cairo context.
 */
function _drawRoundedRect(cr, x, y, w, h, r) {
  const safeR = Math.min(r, w / 2, h / 2);
  cr.newPath();
  cr.arc(x + safeR,     y + safeR,     safeR, Math.PI,       1.5 * Math.PI);
  cr.arc(x + w - safeR, y + safeR,     safeR, 1.5 * Math.PI, 2 * Math.PI);
  cr.arc(x + w - safeR, y + h - safeR, safeR, 0,             0.5 * Math.PI);
  cr.arc(x + safeR,     y + h - safeR, safeR, 0.5 * Math.PI, Math.PI);
  cr.closePath();
}

/**
 * Returns [r, g, b] float values for a given color level.
 * Colors match GNOME Material-style: green/yellow/orange/red.
 */
function _rgbForLevel(level) {
  if (level === 'red')    return [0.937, 0.325, 0.314]; // #ef5250
  if (level === 'orange') return [1.000, 0.596, 0.000]; // #ff9800
  if (level === 'yellow') return [1.000, 0.757, 0.027]; // #ffc107
  return [0.298, 0.686, 0.314]; // #4caf50 green
}
