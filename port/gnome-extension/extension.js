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
import { buildPopupRows } from './lib/popup-view.js';
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
        const cmd = getBatteryCoreLoginCommand(GLib.get_home_dir());
        const proc = Gio.Subprocess.new(cmd, Gio.SubprocessFlags.NONE);
        proc.init(null);
        this._refresh();
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
 * Uses PopupMenu.PopupMenuItem directly to support CSS style_class.
 *
 * @param {object} menu - PanelMenu.Menu instance
 * @param {object|null} state
 */
function _buildPopupContent(menu, state) {
  const rows = buildPopupRows(state);

  for (const row of rows) {
    if (row.message != null) {
      const item = new PopupMenu.PopupMenuItem(row.message);
      if (row.stale) item.label.style_class = 'battery-stale-notice';
      else if (row.error) item.label.style_class = 'battery-error-notice';
      else if (row.loginRequired) item.label.style_class = 'battery-stale-notice';
      item.sensitive = false;
      menu.addMenuItem(item);
    } else if (row.label != null) {
      const item = new PopupMenu.PopupMenuItem(`${row.label}: ${row.value}`);
      item.sensitive = false;
      menu.addMenuItem(item);
    }
  }
}
