#!/usr/bin/env node
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');

const qmlFile = path.resolve(__dirname, '../FileSets/VersionIndependent/opt/victronenergy/gui/qml/PageSettingsExpanderPiDbusAdc.qml');
const source = fs.readFileSync(qmlFile, 'utf8');

function extractFunction(name) {
  const headerRegex = new RegExp(`function\\s+${name}\\s*\\(([^)]*)\\)\\s*\\{`, 'm');
  const match = headerRegex.exec(source);
  if (!match) {
    throw new Error(`Konnte Funktion ${name} nicht finden.`);
  }
  const args = match[1];
  const bodyStart = match.index + match[0].length - 1; // position of opening brace
  let index = bodyStart;
  let depth = 0;
  for (; index < source.length; index += 1) {
    const char = source[index];
    if (char === '{') {
      depth += 1;
    } else if (char === '}') {
      depth -= 1;
      if (depth === 0) {
        index += 1; // include closing brace
        break;
      }
    }
  }
  const body = source.slice(bodyStart, index);
  return `function ${name}(${args}) ${body}`;
}

function extractObjectLiteral(name) {
  const propertyIndex = source.indexOf(`${name}:`);
  if (propertyIndex === -1) {
    throw new Error(`Konnte Eigenschaft ${name} nicht finden.`);
  }
  const openBraceIndex = source.indexOf('{', propertyIndex);
  if (openBraceIndex === -1) {
    throw new Error(`Konnte Startklammer für ${name} nicht finden.`);
  }
  let depth = 0;
  let index = openBraceIndex;
  for (; index < source.length; index += 1) {
    const char = source[index];
    if (char === '{') {
      depth += 1;
    } else if (char === '}') {
      depth -= 1;
      if (depth === 0) {
        index += 1;
        break;
      }
    }
  }
  const objectLiteral = source.slice(openBraceIndex, index);
  return objectLiteral;
}

function extractArrayLiteral(name) {
  const propertyIndex = source.indexOf(`${name}:`);
  if (propertyIndex === -1) {
    throw new Error(`Konnte Eigenschaft ${name} nicht finden.`);
  }
  const openBracketIndex = source.indexOf('[', propertyIndex);
  if (openBracketIndex === -1) {
    throw new Error(`Konnte Startklammer für ${name} nicht finden.`);
  }
  let depth = 0;
  let index = openBracketIndex;
  for (; index < source.length; index += 1) {
    const char = source[index];
    if (char === '[') {
      depth += 1;
    } else if (char === ']') {
      depth -= 1;
      if (depth === 0) {
        index += 1;
        break;
      }
    }
  }
  const arrayLiteral = source.slice(openBracketIndex, index);
  return arrayLiteral;
}

const sandbox = {
  qsTr(text) {
    const stringObject = new String(text);
    stringObject._currentValue = text;
    stringObject._nextIndex = 1;
    stringObject.arg = function replacePlaceholder(value) {
      const placeholder = `%${this._nextIndex}`;
      this._currentValue = this._currentValue.replace(placeholder, value);
      this._nextIndex += 1;
      return this;
    };
    stringObject.toString = function toString() {
      return this._currentValue;
    };
    stringObject.valueOf = function valueOf() {
      return this._currentValue;
    };
    return stringObject;
  }
};
vm.createContext(sandbox);

const canonicalMapLiteral = extractObjectLiteral('sensorTypeCanonicalMap');
vm.runInContext(`const sensorTypeCanonicalMap = ${canonicalMapLiteral};`, sandbox);

const defaultChannelSetupLiteral = extractArrayLiteral('defaultChannelSetup');
vm.runInContext(`const defaultChannelSetup = ${defaultChannelSetupLiteral};`, sandbox);

const functionsToLoad = ['canonicalSensorType', 'defaultLabelForType', 'sensorSummary', 'ensureChannelDefault', 'reloadFromPersistedState'];
for (const fnName of functionsToLoad) {
  const fnSource = extractFunction(fnName);
  vm.runInContext(fnSource, sandbox);
}

const { canonicalSensorType, defaultLabelForType, sensorSummary, reloadFromPersistedState } = sandbox;

assert.equal(canonicalSensorType('Temperatur'), 'temp');
assert.equal(canonicalSensorType('Temperatur-Sensor'), 'temp');
assert.equal(canonicalSensorType('temperature sensor'), 'temp');
assert.equal(canonicalSensorType('Tank-Sensor'), 'tank');
assert.equal(canonicalSensorType('tank sensor'), 'tank');
assert.equal(canonicalSensorType('Nicht belegt'), 'none');
assert.equal(canonicalSensorType('leer'), 'none');
assert.equal(canonicalSensorType('AUS'), 'none');
assert.equal(canonicalSensorType('Voltage'), 'none');
assert.equal(canonicalSensorType('Aus-geschaltet'), 'none');

assert.equal(String(defaultLabelForType('tank', 0)), 'Tank 1');
assert.equal(String(defaultLabelForType('Temp', 1)), 'Temperatur 2');
assert.equal(String(defaultLabelForType('none', 3)), '');

assert.equal(String(sensorSummary('Tank', 'Tank 1', 0)), 'Tank 1 • Tank');
assert.equal(String(sensorSummary('Temp', '', 1)), 'Temperatur • Temperatur');
assert.equal(String(sensorSummary('Voltage', '', 2)), 'Kanal 3: Nicht unterstützter Typ (Voltage)');
assert.equal(String(sensorSummary('NONE', '', 1)), 'Kanal 2 deaktiviert');

console.log('Alle Sensor-Zusammenfassungs-Tests erfolgreich.');

function createVBusItem(initialValue) {
  return {
    valid: true,
    value: initialValue,
    setValue(newValue) {
      this.value = newValue;
    }
  };
}

function createChannelBinding(index, typeValue, labelValue) {
  return {
    channelIndex: index,
    typeItem: createVBusItem(typeValue),
    labelItem: createVBusItem(labelValue)
  };
}

const defaultChannelSetup = sandbox.defaultChannelSetup;
const channelCount = Array.isArray(defaultChannelSetup) ? defaultChannelSetup.length : 0;
const channelBindings = new Array(channelCount);

for (let i = 0; i < channelCount; i += 1) {
  const binding = createChannelBinding(i, 'temp', `Benutzerdefiniert ${i + 1}`);
  channelBindings[i] = binding;
}

// Erzwinge einen Fallback-Fall ohne Default-Eintrag.
if (channelBindings.length > 0) {
  channelBindings[0].channelIndex = 42;
}

sandbox.channelBindings = channelBindings;
sandbox.channelCount = channelCount;
sandbox.vrefItem = createVBusItem('2.500');
sandbox.scaleItem = createVBusItem('1000');

reloadFromPersistedState();

assert.equal(String(sandbox.vrefItem.value), '1.300');
assert.equal(String(sandbox.scaleItem.value), '4095');

for (let i = 0; i < channelBindings.length; i += 1) {
  const binding = channelBindings[i];
  const defaults = sandbox.defaultChannelSetup[binding.channelIndex] || { type: 'none', label: '' };
  const expectedType = canonicalSensorType(defaults.type || 'none');
  assert.equal(binding.typeItem.value, expectedType, `Typ für Kanalindex ${binding.channelIndex} sollte ${expectedType} sein.`);

  let expectedLabel = defaults.label;
  if (expectedLabel === undefined || expectedLabel === null) {
    expectedLabel = defaultLabelForType(expectedType, binding.channelIndex);
  }
  if (expectedType === 'none') {
    expectedLabel = '';
  }
  if (expectedLabel === undefined || expectedLabel === null) {
    expectedLabel = '';
  }

  assert.equal(String(binding.labelItem.value), String(expectedLabel), `Label für Kanalindex ${binding.channelIndex} sollte zurückgesetzt werden.`);
}

console.log('Tests für das Zurücksetzen auf Standardwerte erfolgreich.');
