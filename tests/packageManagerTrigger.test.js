const assert = require('assert');

class MockVBusItem {
  constructor(initialValue, changeHandler) {
    this.valid = true;
    this._value = initialValue;
    this._changeHandler = changeHandler;
  }

  get value() {
    return this._value;
  }

  setValue(newValue) {
    this._value = newValue;
    if (typeof this._changeHandler === 'function') {
      this._changeHandler();
    }
  }
}

function createRootContext() {
  const root = {
    localStatusMessage: '',
    installRequestPending: false,
    packageStatusItem: null,
    packageActionItem: null
  };

  function handlePackageStatusChange() {
    if (!root.packageStatusItem.valid) {
      return;
    }
    const statusText = root.packageStatusItem.value !== undefined && root.packageStatusItem.value !== null
      ? String(root.packageStatusItem.value).trim()
      : '';
    if (statusText.length > 0) {
      root.localStatusMessage = '';
    }
  }

  function handlePackageActionChange() {
    if (!root.packageActionItem.valid) {
      return;
    }
    const actionValue = root.packageActionItem.value !== undefined && root.packageActionItem.value !== null
      ? String(root.packageActionItem.value)
      : '';
    if (actionValue === 'ERROR') {
      root.installRequestPending = false;
      const errorMessage = root.packageStatusItem.valid && root.packageStatusItem.value
        ? String(root.packageStatusItem.value)
        : 'Fehler beim Installationslauf.';
      root.localStatusMessage = errorMessage;
    } else if (actionValue.length === 0 && root.installRequestPending) {
      root.installRequestPending = false;
      if (root.packageStatusItem.valid && root.packageStatusItem.value) {
        const statusText = String(root.packageStatusItem.value).trim();
        if (statusText.length === 0) {
          root.localStatusMessage = 'Installationslauf ausgelöst.';
        }
      } else {
        root.localStatusMessage = 'Installationslauf ausgelöst.';
      }
    }
  }

  root.packageStatusItem = new MockVBusItem('', handlePackageStatusChange);
  root.packageActionItem = new MockVBusItem('', handlePackageActionChange);

  Object.defineProperty(root, 'packageManagerAvailable', {
    get() {
      return root.packageActionItem.valid && root.packageStatusItem.valid;
    }
  });

  Object.defineProperty(root, 'currentStatusText', {
    get() {
      if (!root.packageManagerAvailable) {
        return 'PackageManager-Dienst nicht verfügbar.';
      }
      if (root.localStatusMessage && root.localStatusMessage.length > 0) {
        return root.localStatusMessage;
      }
      if (root.packageStatusItem.valid) {
        const raw = root.packageStatusItem.value;
        if (raw !== undefined && raw !== null) {
          const text = String(raw).trim();
          if (text.length > 0) {
            return text;
          }
        }
      }
      return '';
    }
  });

  root.triggerInstall = function triggerInstall() {
    if (!root.packageActionItem.valid) {
      root.localStatusMessage = 'PackageManager-Dienst nicht verfügbar.';
      if (root.packageStatusItem.valid) {
        root.packageStatusItem.setValue(root.localStatusMessage);
      }
      return false;
    }

    const currentAction = root.packageActionItem.value;
    if (currentAction !== undefined && currentAction !== null && String(currentAction).length > 0) {
      const busyMessage = `PackageManager beschäftigt (${String(currentAction)})`;
      root.localStatusMessage = busyMessage;
      return false;
    }

    root.installRequestPending = true;
    const startMessage = 'Setup wird gestartet …';
    root.localStatusMessage = startMessage;
    if (root.packageStatusItem.valid) {
      root.packageStatusItem.setValue(startMessage);
    }
    root.packageActionItem.setValue('install:ExpanderPiSetup');
    return true;
  };

  return root;
}

function testTriggerInstallHappyPath() {
  const root = createRootContext();
  const result = root.triggerInstall();
  assert.strictEqual(result, true, 'triggerInstall sollte true liefern');
  assert.strictEqual(root.packageActionItem.value, 'install:ExpanderPiSetup', 'GuiEditAction muss Installationsauftrag erhalten');
  assert.strictEqual(root.packageStatusItem.value, 'Setup wird gestartet …', 'GuiEditStatus enthält Startmeldung');
  assert.strictEqual(root.currentStatusText, 'Setup wird gestartet …', 'Statusanzeige zeigt Startmeldung an');

  // simulate PackageManager clearing action and status
  root.packageStatusItem.setValue('install ExpanderPiSetup');
  root.packageStatusItem.setValue('');
  root.packageActionItem.setValue('');
  assert.strictEqual(root.installRequestPending, false, 'Pending-Flag wird zurückgesetzt');
  assert.strictEqual(root.currentStatusText, 'Installationslauf ausgelöst.', 'Statusanzeige fällt auf lokale Bestätigung zurück');
}

function testTriggerInstallBusy() {
  const root = createRootContext();
  root.packageActionItem.setValue('install:SetupHelper');
  const result = root.triggerInstall();
  assert.strictEqual(result, false, 'triggerInstall muss false liefern, wenn Auftrag läuft');
  assert.strictEqual(root.currentStatusText, 'PackageManager beschäftigt (install:SetupHelper)', 'Busy-Status muss angezeigt werden');
}

function testTriggerInstallError() {
  const root = createRootContext();
  const result = root.triggerInstall();
  assert.strictEqual(result, true, 'Vorbereitung muss funktionieren');
  // simulate error propagation
  root.packageStatusItem.setValue('Fehler: Download fehlgeschlagen');
  root.packageActionItem.setValue('ERROR');
  assert.strictEqual(root.installRequestPending, false, 'Pending-Flag wird nach Fehler entfernt');
  assert.strictEqual(root.currentStatusText, 'Fehler: Download fehlgeschlagen', 'Fehlermeldung muss angezeigt werden');
}

function run() {
  testTriggerInstallHappyPath();
  testTriggerInstallBusy();
  testTriggerInstallError();
  console.log('Alle Simulationstests erfolgreich.');
}

if (require.main === module) {
  run();
}

module.exports = {
  createRootContext,
  testTriggerInstallHappyPath,
  testTriggerInstallBusy,
  testTriggerInstallError
};
