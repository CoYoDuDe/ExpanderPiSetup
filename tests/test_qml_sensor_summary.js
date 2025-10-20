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

const sandbox = {
  qsTr(text) {
    const stringObject = new String(text);
    stringObject.arg = function replacePlaceholder(value) {
      return text.replace('%1', value);
    };
    return stringObject;
  }
};
vm.createContext(sandbox);

const canonicalMapLiteral = extractObjectLiteral('sensorTypeCanonicalMap');
vm.runInContext(`const sensorTypeCanonicalMap = ${canonicalMapLiteral};`, sandbox);

const functionsToLoad = ['canonicalSensorType', 'defaultLabelForType', 'sensorSummary'];
for (const fnName of functionsToLoad) {
  const fnSource = extractFunction(fnName);
  vm.runInContext(fnSource, sandbox);
}

const { canonicalSensorType, defaultLabelForType, sensorSummary } = sandbox;

assert.equal(canonicalSensorType('VoltSensor'), 'voltage');
assert.equal(canonicalSensorType('Temperatur'), 'temp');
assert.equal(canonicalSensorType('Temperatur-Sensor'), 'temp');
assert.equal(canonicalSensorType('Tank-Sensor'), 'tank');
assert.equal(canonicalSensorType('tank sensor'), 'tank');
assert.equal(canonicalSensorType('voltage sensor'), 'voltage');
assert.equal(canonicalSensorType('Voltage-Sensor'), 'voltage');
assert.equal(canonicalSensorType('Spannung sensor'), 'voltage');
assert.equal(canonicalSensorType('current sensor'), 'current');
assert.equal(canonicalSensorType('Pressure-Sensor'), 'pressure');
assert.equal(canonicalSensorType('humidity sensor'), 'humidity');
assert.equal(canonicalSensorType('temperature sensor'), 'temp');
assert.equal(canonicalSensorType('leer'), 'none');
assert.equal(canonicalSensorType('AUS'), 'none');
assert.equal(canonicalSensorType('Aus-geschaltet'), 'none');

assert.equal(defaultLabelForType('Voltage', 2), 'Spannung 3');
assert.equal(defaultLabelForType('voltage', 2), 'Spannung 3');
assert.equal(defaultLabelForType('VOLTAGE', 2), 'Spannung 3');

assert.equal(sensorSummary('Voltage', 'Spannung 3', 2), 'Spannung 3 • Spannung');
assert.equal(sensorSummary('Voltage', '', 2), 'Spannung • Spannung');
assert.equal(sensorSummary('MyCustomType', '', 0), 'MyCustomType • MyCustomType');
assert.equal(sensorSummary('NONE', '', 1), 'Kanal 2 deaktiviert');

console.log('Alle Sensor-Zusammenfassungs-Tests erfolgreich.');
