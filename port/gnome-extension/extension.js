/**
 * Battery GNOME Shell Extension
 *
 * Thin shell integration layer. All logic lives in lib/.
 * Reads ~/.battery/state.json via Gio and renders a top-bar indicator.
 */
import GLib from 'gi://GLib';
import Gio from 'gi://Gio';
import St from 'gi://St';
import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';

import { getIndicatorLabel } from './lib/status-model.js';
import { readStateFile } from './lib/state-reader.js';
import { buildPopupContent } from './lib/popup-view.js';

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

class BatteryIndicator extends PanelMenu.Button {
  _init(extension) {
    super._init(0.0, 'Battery');

    this._extension = extension;
    this._stateFile = GLib.get_home_dir() + '/.battery/state.json';

    this._label = new St.Label({
      text: 'Battery …',
      y_align: 2, // Clutter.ActorAlign.CENTER
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

    // Manual refresh menu item
    this.menu.addAction('Refresh', () => this._refresh());
  }

  _refresh() {
    const state = readStateFile(this._stateFile);
    this._label.set_text(getIndicatorLabel(state));
    this.menu.removeAll();
    buildPopupContent(this.menu, state);
    this.menu.addAction('Refresh', () => this._refresh());
  }

  destroy() {
    if (this._timerId) {
      GLib.source_remove(this._timerId);
      this._timerId = null;
    }
    super.destroy();
  }
}
