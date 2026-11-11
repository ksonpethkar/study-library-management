// Compiles a dart2wasm-generated main module from `source` which can then
// be instantiated via the `instantiate` method.
//
// `source` needs to be a `Response` object (or promise thereof) e.g. created
// via the `fetch()` JS API.
export async function compileStreaming(source) {
  const builtins = {builtins: ['js-string']};
  return new CompiledApp(
      await WebAssembly.compileStreaming(source, builtins), builtins);
}

// Compiles a dart2wasm-generated wasm module from `bytes` which is then
// instantiable via the `instantiate` method.
export async function compile(bytes) {
  const builtins = {builtins: ['js-string']};
  return new CompiledApp(await WebAssembly.compile(bytes, builtins), builtins);
}

class CompiledApp {
  constructor(module, builtins) {
    this.module = module;
    this.builtins = builtins;
  }

  // The second argument is an options object containing:
  // `loadDeferredModules` is a JS function that takes an array of module names
  //   matching wasm files produced by the dart2wasm compiler. It also takes a
  //   callback that should be invoked for each loaded module with 2 arguments:
  //   (1) the module name, (2) the loaded module in a format supported by
  //   `WebAssembly.compile` or `WebAssembly.compileStreaming`. The callback
  //   returns a Promise that resolves when the module is instantiated.
  //   loadDeferredModules should return a Promise that resolves when all the
  //   modules have been loaded and the callback promises have resolved.
  // `loadDeferredId` is a JS function that takes load ID produced by the
  //   compiler when the `use-load-ids` option is passed. Each load ID maps to
  //   one or more wasm files as specified in the emitted JSON file. It also
  //   takes a callback that should be invoked for each loaded module with 2
  //   arguments: (1) the module name, (2) the loaded module in a format
  //   supported by `WebAssembly.compile` or `WebAssembly.compileStreaming`.
  //   The callback returns a Promise that resolves when the module is
  //   instantiated.
  //   loadDeferredId should return a Promise that resolves when all the
  //   modules have been loaded and the callback promises have resolved.
  async instantiate(additionalImports, {loadDeferredModules, loadDeferredId} = {}) {
    let dartInstance;

    // Prints to the console
    function printToConsole(value) {
      if (typeof dartPrint == "function") {
        dartPrint(value);
        return;
      }
      if (typeof console == "object" && typeof console.log != "undefined") {
        console.log(value);
        return;
      }
      if (typeof print == "function") {
        print(value);
        return;
      }

      throw "Unable to print message: " + value;
    }

    // A special symbol attached to functions that wrap Dart functions.
    const jsWrappedDartFunctionSymbol = Symbol("JSWrappedDartFunction");

    function finalizeWrapper(dartFunction, wrapped) {
      wrapped.dartFunction = dartFunction;
      wrapped[jsWrappedDartFunctionSymbol] = true;
      return wrapped;
    }

    // Imports
    const dart2wasm = {
            AB: (x0,x1,x2,x3) => x0.addEventListener(x1,x2,x3),
      AC: Function.prototype.call.bind(DataView.prototype.setInt16),
      AD: x0 => x0.height,
      AE: (x0,x1) => x0.observe(x1),
      AF: x0 => x0.wheelDeltaY,
      AG: x0 => x0.parentElement,
      AH: x0 => x0.readText(),
      AI: x0 => x0.stopPropagation(),
      AJ: x0 => x0.style,
      AK: () => globalThis.Notification.permission,
      AL: x0 => globalThis.fetch(x0),
      AM: (x0,x1) => { x0.scale = x1 },
      AN: () => ({}),
      AO: x0 => x0.videoHeight,
      AP: x0 => x0.files,
      AQ: (x0,x1) => ({next: x0,error: x1}),
      AR: x0 => x0.lastSignInTime,
      AS: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      AT: () => globalThis.firebase_firestore.deleteField(),
      AU: () => globalThis.firebase_firestore.startAt,
      B: s => printToConsole(s),
      BB: b => !!b,
      BC: Function.prototype.call.bind(DataView.prototype.setUint16),
      BD: x0 => x0.width,
      BE: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      BF: x0 => x0.wheelDeltaX,
      BG: (x0,x1) => x0.querySelectorAll(x1),
      BH: x0 => x0.clipboard,
      BI: x0 => x0.disabled,
      BJ: (x0,x1) => { x0.src = x1 },
      BK: o => o.byteLength,
      BL: x0 => x0.arrayBuffer(),
      BM: x0 => x0.document,
      BN: (x0,x1) => x0.applyConstraints(x1),
      BO: x0 => x0.videoWidth,
      BP: x0 => x0.target,
      BQ: (x0,x1) => globalThis.firebase_messaging.onRegistered(x0,x1),
      BR: x0 => x0.creationTime,
      BS: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      BT: x0 => x0.id,
      BU: (x0,x1) => globalThis.firebase_firestore.orderBy(x0,x1),
      C: Function.prototype.call.bind(Number.prototype.toString),
      CB: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      CC: Function.prototype.call.bind(DataView.prototype.setUint8),
      CD: x0 => x0.screen,
      CE: x0 => new ResizeObserver(x0),
      CF: x0 => x0.key,
      CG: (x0,x1) => x0.requestAnimationFrame(x1),
      CH: (x0,x1) => x0.writeText(x1),
      CI: (x0,x1) => { x0.min = x1 },
      CJ: () => globalThis.document,
      CK: () => new FileReader(),
      CL: x0 => x0.baseURI,
      CM: x0 => x0.numPages,
      CN: (x0,x1) => { x0.whiteBalanceMode = x1 },
      CO: x0 => x0.stream,
      CP: (x0,x1) => x0.replaceChildren(x1),
      CQ: x0 => x0.link,
      CR: x0 => x0.metadata,
      CS: (x0,x1,x2) => x0.onIdTokenChanged(x1,x2),
      CT: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      CU: x0 => x0.metadata,
      D: Function.prototype.call.bind(BigInt.prototype.toString),
      DB: (x0,x1) => x0.focus(x1),
      DC: Function.prototype.call.bind(DataView.prototype.setInt8),
      DD: o => {
        if (o === null || o === undefined) return 0;
        if (typeof(o) === 'string') return 1;
        return 2;
      },
      DE: (x0,x1) => x0.getPropertyValue(x1),
      DF: x0 => x0.identifier,
      DG: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      DH: x0 => x0.unlock(),
      DI: (x0,x1) => { x0.max = x1 },
      DJ: x0 => x0.src,
      DK: (x0,x1) => x0.readAsArrayBuffer(x1),
      DL: x0 => x0.canvasKitMaximumSurfaces,
      DM: x0 => x0.promise,
      DN: x0 => x0.whiteBalanceMode,
      DO: x0 => x0.play(),
      DP: (x0,x1) => { x0.accept = x1 },
      DQ: x0 => x0.analyticsLabel,
      DR: x0 => x0.isAnonymous,
      DS: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      DT: x0 => ({maxAttempts: x0}),
      DU: x0 => x0.doc,
      E: (exn) => {
        let stackString = exn.toString();
        let frames = stackString.split('\n');
        let drop = 4;
        if (frames[0].startsWith('Error')) {
            drop += 1;
        }
        return frames.slice(drop).join('\n');
      },
      EB: () => ({}),
      EC: Function.prototype.call.bind(DataView.prototype.getInt8),
      ED: x0 => x0.tabIndex,
      EE: x0 => globalThis.parseFloat(x0),
      EF: x0 => x0.touches,
      EG: x0 => x0.now(),
      EH: (x0,x1) => x0.lock(x1),
      EI: (x0,x1) => { x0.disabled = x1 },
      EJ: x0 => x0.decode(),
      EK: x0 => x0.result,
      EL: x0 => x0.nextSibling,
      EM: (x0,x1) => { x0.cMapPacked = x1 },
      EN: (x0,x1) => { x0.exposureMode = x1 },
      EO: x0 => x0.paused,
      EP: (x0,x1) => { x0.multiple = x1 },
      EQ: x0 => x0.image,
      ER: x0 => x0.emailVerified,
      ES: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      ET: (x0,x1,x2) => globalThis.firebase_firestore.runTransaction(x0,x1,x2),
      EU: x0 => x0.newIndex,
      F: () => new Error().stack,
      FB: (o, p, v) => o[p] = v,
      FC: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Int8Array) return 1;
        return 2;
      },
      FD: (x0,x1) => x0.contains(x1),
      FE: (x0,x1) => x0.getComputedStyle(x1),
      FF: x0 => x0.pressure,
      FG: x0 => x0.performance,
      FH: x0 => x0.orientation,
      FI: (x0,x1) => { x0.scrollLeft = x1 },
      FJ: (x0,x1,x2,x3) => x0.open(x1,x2,x3),
      FK: (x0,x1,x2,x3) => x0.addEventListener(x1,x2,x3),
      FL: (x0,x1) => x0.debug(x1),
      FM: (x0,x1) => { x0.cMapUrl = x1 },
      FN: x0 => x0.exposureMode,
      FO: (x0,x1,x2,x3) => x0.drawImage(x1,x2,x3),
      FP: (x0,x1) => { x0.type = x1 },
      FQ: x0 => x0.body,
      FR: x0 => x0.email,
      FS: (x0,x1,x2) => x0.onAuthStateChanged(x1,x2),
      FT: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      FU: x0 => x0.oldIndex,
      G: s => JSON.stringify(s),
      GB: () => [],
      GC: (o, start, length) => new Float64Array(o.buffer, o.byteOffset + start, length),
      GD: x0 => x0.activeElement,
      GE: x0 => x0.documentElement,
      GF: x0 => x0.tiltY,
      GG: (d, digits) => d.toFixed(digits),
      GH: (x0,x1) => x0.querySelector(x1),
      GI: (x0,x1) => { x0.spellcheck = x1 },
      GJ: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      GK: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      GL: x0 => x0.hostElement,
      GM: (x0,x1) => { x0.data = x1 },
      GN: (x0,x1) => { x0.focusMode = x1 },
      GO: (x0,x1,x2,x3,x4) => x0.getImageData(x1,x2,x3,x4),
      GP: (x0,x1) => x0.getAttribute(x1),
      GQ: x0 => x0.title,
      GR: x0 => x0.displayName,
      GS: x0 => x0.currentUser,
      GT: (o,s,v) => o[s] = v,
      GU: x0 => x0.type,
      H: Function.prototype.call.bind(Number.prototype.toString),
      HB: (a, i) => a.push(i),
      HC: (o, start, length) => new Float32Array(o.buffer, o.byteOffset + start, length),
      HD: x0 => x0.parentNode,
      HE: x0 => x0.computedStyleMap(),
      HF: x0 => x0.tiltX,
      HG: x0 => x0.maxHeight,
      HH: (x0,x1) => { x0.title = x1 },
      HI: (x0,x1) => { x0.disabled = x1 },
      HJ: (x0,x1,x2) => x0.addEventListener(x1,x2),
      HK: (x0,x1,x2,x3) => x0.removeEventListener(x1,x2,x3),
      HL: x0 => x0.location,
      HM: x0 => ({type: x0}),
      HN: x0 => x0.focusMode,
      HO: (x0,x1,x2) => x0.readBarcodes(x1,x2),
      HP: (x0,x1) => x0.debug(x1),
      HQ: x0 => x0.fcmOptions,
      HR: x0 => globalThis.firebase_auth.multiFactor(x0),
      HS: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      HT: () => Symbol("jsBoxedDartObjectProperty"),
      HU: x0 => x0.docChanges(),
      I: Function.prototype.call.bind(String.prototype.indexOf),
      IB: x0 => new Int8Array(x0),
      IC: (o, start, length) => new Uint32Array(o.buffer, o.byteOffset + start, length),
      ID: x0 => x0.tagName,
      IE: (x0,x1) => x0.get(x1),
      IF: x0 => x0.pointerType,
      IG: x0 => x0.maxWidth,
      IH: (x0,x1) => x0.vibrate(x1),
      II: (x0,x1) => x0.getRandomValues(x1),
      IJ: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      IK: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      IL: (x0,x1) => x0.getModifierState(x1),
      IM: (x0,x1) => new Blob(x0,x1),
      IN: x0 => x0.enumerateDevices(),
      IO: x0 => x0.text,
      IP: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      IQ: x0 => x0.notification,
      IR: x0 => x0.toJSON(),
      IS: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      IT: (x0,x1) => x0.delete(x1),
      IU: x0 => x0.docs,
      J: (s, p, i) => s.lastIndexOf(p, i),
      JB: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI8ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      JC: (o, start, length) => new Int32Array(o.buffer, o.byteOffset + start, length),
      JD: x0 => x0.target,
      JE: (o, p) => p in o,
      JF: x0 => x0.pointerId,
      JG: x0 => x0.minHeight,
      JH: x0 => x0.arrayBuffer(),
      JI: () => globalThis.crypto,
      JJ: x0 => x0.send(),
      JK: () => new XMLHttpRequest(),
      JL: x0 => x0.metaKey,
      JM: x0 => globalThis.URL.createObjectURL(x0),
      JN: x0 => x0.deviceId,
      JO: x0 => x0.format,
      JP: x0 => ({createScriptURL: x0}),
      JQ: x0 => x0.messageId,
      JR: x0 => x0.user,
      JS: x0 => x0.hostname,
      JT: (x0,x1,x2,x3) => x0.set(x1,x2,x3),
      JU: (x0,x1) => ({includeMetadataChanges: x0,source: x1}),
      K: o => o,
      KB: x0 => new Uint8Array(x0),
      KC: (o, start, length) => new Uint16Array(o.buffer, o.byteOffset + start, length),
      KD: x0 => x0.clientY,
      KE: (x0,x1) => { x0.textContent = x1 },
      KF: x0 => x0.getCoalescedEvents(),
      KG: x0 => x0.minWidth,
      KH: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof ArrayBuffer) return 1;
        if (globalThis.SharedArrayBuffer !== undefined &&
            o instanceof SharedArrayBuffer) {
          return 2;
        }
        return 3;
      },
      KI: l => new DataView(new ArrayBuffer(l)),
      KJ: (x0,x1) => x0.revokeObjectURL(x1),
      KK: (x0,x1,x2,x3) => x0.open(x1,x2,x3),
      KL: x0 => x0.altKey,
      KM: (x0,x1) => x0.append(x1),
      KN: x0 => x0.kind,
      KO: x0 => x0.bytes,
      KP: (x0,x1,x2) => x0.createPolicy(x1,x2),
      KQ: x0 => x0.from,
      KR: x0 => x0.idToken,
      KS: x0 => x0.location,
      KT: (x0,x1,x2) => x0.set(x1,x2),
      KU: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      L: o => {
        if (o === undefined || o === null) return 0;
        if (typeof o === 'number') return 1;
        return 2;
      },
      LB: x0 => new Uint8ClampedArray(x0),
      LC: (o, start, length) => new Int16Array(o.buffer, o.byteOffset + start, length),
      LD: x0 => x0.clientX,
      LE: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      LF: (x0,x1) => x0.getModifierState(x1),
      LG: (x0,x1) => x0.removeProperty(x1),
      LH: x0 => x0.status,
      LI: (a, i) => a.splice(i, 1),
      LJ: (x0,x1) => { x0.src = x1 },
      LK: x0 => x0.send(),
      LL: x0 => x0.ctrlKey,
      LM: x0 => x0.click(),
      LN: x0 => x0.facingMode,
      LO: x0 => x0.y,
      LP: (x0,x1) => x0.createScriptURL(x1),
      LQ: x0 => x0.collapseKey,
      LR: x0 => x0.secret,
      LS: x0 => x0.token,
      LT: x0 => ({merge: x0}),
      LU: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      M: x0 => x0.index,
      MB: x0 => new Int16Array(x0),
      MC: (o, start, length) => new Uint8ClampedArray(o.buffer, o.byteOffset + start, length),
      MD: (x0,x1,x2) => x0.setAttribute(x1,x2),
      ME: x0 => x0.matches,
      MF: s => s.trimLeft(),
      MG: (x0,x1) => x0.add(x1),
      MH: (x0,x1) => x0.fetch(x1),
      MI: a => a.pop(),
      MJ: (x0,x1,x2,x3,x4) => globalThis.createImageBitmap(x0,x1,x2,x3,x4),
      MK: x0 => x0.type,
      ML: x0 => x0.isComposing,
      MM: x0 => x0.remove(),
      MN: x0 => x0.mediaDevices,
      MO: x0 => x0.x,
      MP: (x0,x1) => { x0.nonce = x1 },
      MQ: x0 => x0.data,
      MR: x0 => x0.accessToken,
      MS: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      MT: x0 => ({serverTimestamps: x0}),
      MU: (x0,x1,x2,x3) => globalThis.firebase_firestore.onSnapshot(x0,x1,x2,x3),
      N: o => String(o),
      NB: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI16ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      NC: (o, start, length) => new Uint8Array(o.buffer, o.byteOffset + start, length),
      ND: x0 => x0.getBoundingClientRect(),
      NE: (x0,x1) => x0.matchMedia(x1),
      NF: s => s.toUpperCase(),
      NG: x0 => x0.data,
      NH: x0 => x0.content,
      NI: (map, o, v) => map.set(o, v),
      NJ: x0 => x0.naturalHeight,
      NK: x0 => x0.response,
      NL: x0 => x0.code,
      NM: x0 => x0.body,
      NN: () => globalThis.BarcodeDetector.getSupportedFormats(),
      NO: x0 => x0.bottomLeft,
      NP: (x0,x1) => x0.querySelectorAll(x1),
      NQ: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      NR: x0 => x0.signInMethod,
      NS: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      NT: x0 => x0.fromCache,
      NU: x0 => globalThis.firebase_firestore.getDocs(x0),
      O: o => o === undefined,
      OB: x0 => new Uint16Array(x0),
      OC: (o, start, length) => new Int8Array(o.buffer, o.byteOffset + start, length),
      OD: (ms, c) =>
      setTimeout(() => dartInstance.exports.$invokeCallback(c),ms),
      OE: x0 => x0.matches,
      OF: x0 => x0.pop(),
      OG: (x0,x1) => { x0.scrollTop = x1 },
      OH: x0 => x0.document,
      OI: (map, o) => map.get(o),
      OJ: x0 => x0.naturalWidth,
      OK: (x0,x1) => { x0.responseType = x1 },
      OL: x0 => x0.repeat,
      OM: (x0,x1) => { x0.target = x1 },
      ON: (x0,x1) => x0.call(x1),
      OO: x0 => x0.bottomRight,
      OP: (x0,x1) => x0.item(x1),
      OQ: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      OR: x0 => x0.providerId,
      OS: (x0,x1,x2) => globalThis.firebase_app_check.onTokenChanged(x0,x1,x2),
      OT: x0 => x0.hasPendingWrites,
      OU: x0 => globalThis.firebase_firestore.getDocsFromServer(x0),
      P: (x0,x1) => x0.exec(x1),
      PB: x0 => new Int32Array(x0),
      PC: (x0,x1) => x0.querySelector(x1),
      PD: s => new Date(s * 1000).getTimezoneOffset() * 60,
      PE: o => typeof o === 'function' && o[jsWrappedDartFunctionSymbol] === true,
      PF: x0 => x0.flags,
      PG: (x0,x1,x2) => x0.setSelectionRange(x1,x2),
      PH: () => typeof dartUseDateNowForTicks !== "undefined",
      PI: () => new WeakMap(),
      PJ: x0 => x0.decode(),
      PK: x0 => x0.vendor,
      PL: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      PM: (x0,x1) => { x0.download = x1 },
      PN: x0 => x0.reset,
      PO: x0 => x0.topRight,
      PP: x0 => x0.nonce,
      PQ: (x0,x1) => globalThis.firebase_messaging.onMessage(x0,x1),
      PR: x0 => globalThis.firebase_auth.OAuthProvider.credentialFromResult(x0),
      PS: x0 => new firebase_app_check.ReCaptchaV3Provider(x0),
      PT: x0 => x0.metadata,
      PU: x0 => globalThis.firebase_firestore.getDocsFromCache(x0),
      Q: (x0,x1) => { x0.lastIndex = x1 },
      QB: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI32ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      QC: (x0,x1) => x0.item(x1),
      QD: Date.now,
      QE: f => f.dartFunction,
      QF: (a, s) => a.join(s),
      QG: (x0,x1) => { x0.value = x1 },
      QH: () => Date.now(),
      QI: x0 => new WeakRef(x0),
      QJ: (x0,x1) => { x0.decoding = x1 },
      QK: x0 => x0.navigator,
      QL: x0 => x0.userAgent,
      QM: (x0,x1) => { x0.href = x1 },
      QN: x0 => x0.stopContinuousDecode,
      QO: x0 => x0.topLeft,
      QP: x0 => x0.length,
      QQ: x0 => globalThis.firebase_messaging.getMessaging(x0),
      QR: x0 => x0.username,
      QS: x0 => new firebase_app_check.ReCaptchaEnterpriseProvider(x0),
      QT: x0 => x0.toArray(),
      QU: x0 => x0.source,
      R: o => o,
      RB: x0 => new Uint32Array(x0),
      RC: x0 => x0.length,
      RD: (handle) => clearTimeout(handle),
      RE: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      RF: (x0,x1) => x0.error(x1),
      RG: (x0,x1,x2) => x0.setSelectionRange(x1,x2),
      RH: () => 1000 * performance.now(),
      RI: x0 => x0.deref(),
      RJ: (x0,x1) => { x0.crossOrigin = x1 },
      RK: () => globalThis.window,
      RL: (x0,x1,x2,x3) => x0.open(x1,x2,x3),
      RM: () => globalThis.document,
      RN: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      RO: x0 => x0.position,
      RP: (x0,x1) => { x0.src = x1 },
      RQ: (x0,x1) => globalThis.firebase_messaging.register(x0,x1),
      RR: x0 => x0.providerId,
      RS: x0 => ({provider: x0}),
      RT: x0 => x0.toUint8Array(),
      RU: x0 => ({source: x0}),
      S: (s, m) => {
        try {
          return new RegExp(s, m);
        } catch (e) {
          return String(e);
        }
      },
      SB: x0 => new Float32Array(x0),
      SC: (x0,x1) => x0.querySelectorAll(x1),
      SD: (x0,x1) => x0.closest(x1),
      SE: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      SF: () => globalThis.console,
      SG: (x0,x1) => { x0.value = x1 },
      SH: x0 => new Uint8Array(x0),
      SI: () => globalThis.WeakRef,
      SJ: (x0,x1) => x0.createObjectURL(x1),
      SK: x0 => new Blob(x0),
      SL: (x0,x1) => x0.getItem(x1),
      SM: (x0,x1) => x0.getElementById(x1),
      SN: (x0,x1,x2,x3) => x0.call(x1,x2,x3),
      SO: x0 => x0.isValid,
      SP: x0 => x0.trustedTypes,
      SQ: x0 => x0.measurementId,
      SR: x0 => x0.profile,
      SS: (x0,x1) => globalThis.firebase_app_check.initializeAppCheck(x0,x1),
      ST: () => globalThis.firebase_firestore.Bytes,
      SU: (x0,x1) => globalThis.firebase_firestore.collectionGroup(x0,x1),
      T: o => o instanceof RegExp,
      TB: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmF32ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      TC: (x0,x1) => x0.getAttribute(x1),
      TD: x0 => x0.bottom,
      TE: (p, s, f) => p.then(s, (e) => f(e, e === undefined)),
      TF: s => s.trimRight(),
      TG: s => {
        if (/[[\]{}()*+?.\\^$|]/.test(s)) {
            s = s.replace(/[[\]{}()*+?.\\^$|]/g, '\\$&');
        }
        return s;
      },
      TH: (x0,x1,x2) => x0.slice(x1,x2),
      TI: (o, offsetInBytes, lengthInBytes) => {
        var dst = new ArrayBuffer(lengthInBytes);
        new Uint8Array(dst).set(new Uint8Array(o, offsetInBytes, lengthInBytes));
        return new DataView(dst);
      },
      TJ: x0 => x0.URL,
      TK: x0 => x0.abort(),
      TL: x0 => x0.localStorage,
      TM: (x0,x1,x2) => x0.setAttribute(x1,x2),
      TN: x0 => x0.text,
      TO: (x0,x1,x2,x3) => ({formats: x0,tryHarder: x1,tryRotate: x2,tryInvert: x3}),
      TP: () => globalThis.console,
      TQ: x0 => x0.appId,
      TR: x0 => x0.isNewUser,
      TS: (x0,x1) => globalThis.firebase_analytics.setAnalyticsCollectionEnabled(x0,x1),
      TT: () => globalThis.firebase_firestore.VectorValue,
      TU: x0 => globalThis.firebase_firestore.deleteDoc(x0),
      U: (string, times) => string.repeat(times),
      UB: x0 => new Float64Array(x0),
      UC: x0 => x0.remove(),
      UD: x0 => x0.top,
      UE: (o, i) => o[i],
      UF: x0 => x0.blur(),
      UG: x0 => x0.value,
      UH: (x0,x1) => x0.decode(x1),
      UI: (a, s, e) => a.slice(s, e),
      UJ: x0 => new Blob(x0),
      UK: (x0,x1,x2,x3) => x0.putImageData(x1,x2,x3),
      UL: (x0,x1) => x0.key(x1),
      UM: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      UN: x0 => x0.barcodeFormat,
      UO: (x0,x1,x2) => ({tryHarder: x0,tryRotate: x1,tryInvert: x2}),
      UP: x0 => x0.trustedTypes,
      UQ: x0 => x0.messagingSenderId,
      UR: x0 => globalThis.firebase_auth.getAdditionalUserInfo(x0),
      US: (x0,x1) => globalThis.firebase_analytics.initializeAnalytics(x0,x1),
      UT: x0 => x0.longitude,
      UU: () => globalThis.firebase_firestore.updateDoc,
      V: o => o,
      VB: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmF64ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      VC: (x0,x1) => x0.appendChild(x1),
      VD: x0 => x0.right,
      VE: o => o.length,
      VF: x0 => x0.button,
      VG: x0 => x0.selectionDirection,
      VH: (x0,x1) => x0.adoptText(x1),
      VI: x0 => x0.message,
      VJ: (x0,x1,x2,x3,x4) => ({type: x0,data: x1,premultiplyAlpha: x2,colorSpaceConversion: x3,preferAnimation: x4}),
      VK: x0 => x0.arrayBuffer(),
      VL: x0 => x0.length,
      VM: (x0,x1,x2) => x0.addEventListener(x1,x2),
      VN: x0 => x0.rawBytes,
      VO: () => globalThis.ZXingWASM,
      VP: (wasmFunction,f) => finalizeWrapper(f, function() { return wasmFunction(f,arguments.length) }),
      VQ: x0 => x0.authDomain,
      VR: x0 => globalThis.firebase_auth.OAuthProvider.credentialFromError(x0),
      VS: (o, a) => o + a,
      VT: x0 => x0.latitude,
      VU: x0 => globalThis.firebase_firestore.getDoc(x0),
      W: o => {
        if (o === undefined || o === null) return 0;
        if (typeof o === 'boolean') return 1;
        return 2;
      },
      WB: x0 => new ArrayBuffer(x0),
      WC: (x0,x1) => x0.append(x1),
      WD: x0 => x0.left,
      WE: o => {
        if (o === undefined) return 1;
        var type = typeof o;
        if (type === 'boolean') return 2;
        if (type === 'number') return 3;
        if (type === 'string') return 4;
        if (o instanceof Array) return 5;
        if (ArrayBuffer.isView(o)) {
          if (o instanceof Int8Array) return 6;
          if (o instanceof Uint8Array) return 7;
          if (o instanceof Uint8ClampedArray) return 8;
          if (o instanceof Int16Array) return 9;
          if (o instanceof Uint16Array) return 10;
          if (o instanceof Int32Array) return 11;
          if (o instanceof Uint32Array) return 12;
          if (o instanceof Float32Array) return 13;
          if (o instanceof Float64Array) return 14;
          if (o instanceof DataView) return 15;
        }
        if (o instanceof ArrayBuffer) return 16;
        // Feature check for `SharedArrayBuffer` before doing a type-check.
        if (globalThis.SharedArrayBuffer !== undefined &&
            o instanceof SharedArrayBuffer) {
            return 17;
        }
        if (o instanceof Promise) return 18;
        return 19;
      },
      WF: x0 => x0.innerHeight,
      WG: x0 => x0.selectionStart,
      WH: x0 => x0.first(),
      WI: (o, p) => p in o,
      WJ: x0 => new window.ImageDecoder(x0),
      WK: (x0,x1) => x0.transferFromImageBitmap(x1),
      WL: (x0,x1) => x0.removeItem(x1),
      WM: (x0,x1,x2) => x0.removeEventListener(x1,x2),
      WN: x0 => x0.y,
      WO: (x0,x1) => { x0.srcObject = x1 },
      WP: x0 => { globalThis.onGoogleLibraryLoad = x0 },
      WQ: x0 => x0.projectId,
      WR: x0 => x0.session,
      WS: x0 => x0.children,
      WT: () => globalThis.firebase_firestore.GeoPoint,
      WU: x0 => globalThis.firebase_firestore.getDocFromServer(x0),
      X: x0 => x0.dotAll,
      XB: (x0,x1,x2) => new Uint8Array(x0,x1,x2),
      XC: (x0,x1,x2,x3) => x0.setProperty(x1,x2,x3),
      XD: x0 => x0.clientY,
      XE: x0 => x0.language,
      XF: x0 => x0.innerWidth,
      XG: x0 => x0.selectionEnd,
      XH: x0 => x0.next(),
      XI: x0 => x0.groups,
      XJ: x0 => x0.name,
      XK: x0 => x0.height,
      XL: (x0,x1,x2) => x0.setItem(x1,x2),
      XM: (x0,x1) => { x0.innerHTML = x1 },
      XN: x0 => x0.x,
      XO: x0 => ({willReadFrequently: x0}),
      XP: x0 => x0.code,
      XQ: x0 => x0.name,
      XR: x0 => x0.phoneNumber,
      XS: x0 => x0.firstChild,
      XT: (x0,x1) => x0.data(x1),
      XU: x0 => globalThis.firebase_firestore.getDocFromCache(x0),
      Y: x0 => x0.unicode,
      YB: (x0,x1,x2) => new DataView(x0,x1,x2),
      YC: x0 => x0.style,
      YD: x0 => x0.clientX,
      YE: (x0,x1,x2,x3) => x0.register(x1,x2,x3),
      YF: x0 => x0.height,
      YG: x0 => x0.value,
      YH: x0 => x0.current(),
      YI: () => new AbortController(),
      YJ: x0 => x0.repetitionCount,
      YK: x0 => x0.width,
      YL: (x0,x1) => x0.canShare(x1),
      YM: x0 => x0.permissions,
      YN: x0 => x0.resultPoints,
      YO: (x0,x1,x2) => x0.getContext(x1,x2),
      YP: (x0,x1) => globalThis.firebase_storage.ref(x0,x1),
      YQ: (x0,x1,x2,x3,x4,x5,x6,x7) => ({apiKey: x0,authDomain: x1,databaseURL: x2,projectId: x3,storageBucket: x4,messagingSenderId: x5,measurementId: x6,appId: x7}),
      YR: x0 => x0.uid,
      YS: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      YT: x0 => x0.nanoseconds,
      YU: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      Z: x0 => x0.ignoreCase,
      ZB: (o, p) => o[p],
      ZC: x0 => x0.debugShowSemanticsNodes,
      ZD: x0 => x0.changedTouches,
      ZE: () => globalThis.window.FinalizationRegistry,
      ZF: x0 => x0.width,
      ZG: x0 => x0.selectionDirection,
      ZH: (x0,x1) => new Intl.v8BreakIterator(x0,x1),
      ZI: (x0,x1,x2,x3,x4,x5) => ({method: x0,headers: x1,body: x2,credentials: x3,redirect: x4,signal: x5}),
      ZJ: x0 => x0.frameCount,
      ZK: x0 => x0.rasterEndMilliseconds,
      ZL: (x0,x1) => x0.share(x1),
      ZM: x0 => x0.geolocation,
      ZN: x0 => x0.message,
      ZO: () => new BarcodeDetector(),
      ZP: x0 => x0.name,
      ZQ: (x0,x1) => globalThis.firebase_core.initializeApp(x0,x1),
      ZR: x0 => x0.enrollmentTime,
      ZS: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      ZT: x0 => x0.seconds,
      ZU: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      a: x0 => x0.multiline,
      aB: (o) => new DataView(o.buffer, o.byteOffset, o.byteLength),
      aC: (x0,x1) => x0.warn(x1),
      aD: x0 => x0.offsetY,
      aE: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      aF: x0 => x0.clientHeight,
      aG: x0 => x0.selectionStart,
      aH: x0 => x0.v8BreakIterator,
      aI: (x0,x1) => globalThis.fetch(x0,x1),
      aJ: x0 => x0.selectedTrack,
      aK: x0 => x0.rasterStartMilliseconds,
      aL: x0 => x0.message,
      aM: x0 => x0.mediaDevices,
      aN: x0 => x0.videoElement,
      aO: x0 => ({formats: x0}),
      aP: (x0,x1) => globalThis.firebase_storage.getStorage(x0,x1),
      aQ: x0 => globalThis.firebase_core.initializeApp(x0),
      aR: x0 => x0.factorId,
      aS: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      aT: () => globalThis.firebase_firestore.Timestamp,
      aU: (x0,x1,x2) => globalThis.firebase_firestore.onSnapshot(x0,x1,x2),
      b: (exn) => {
        if (exn instanceof Error) {
          return exn.stack;
        } else {
          return null;
        }
      },
      bB: Function.prototype.call.bind(Object.getOwnPropertyDescriptor(DataView.prototype, 'byteLength').get),
      bC: x0 => x0.console,
      bD: x0 => x0.offsetX,
      bE: x0 => new window.FinalizationRegistry(x0),
      bF: x0 => x0.clientWidth,
      bG: x0 => x0.selectionEnd,
      bH: () => globalThis.Intl,
      bI: (x0,x1) => x0.get(x1),
      bJ: x0 => x0.completed,
      bK: x0 => x0.imageBitmaps,
      bL: (x0,x1,x2) => ({files: x0,title: x1,text: x2}),
      bM: x0 => x0.baseURI,
      bN: x0 => x0.decodeContinuously,
      bO: x0 => new BarcodeDetector(x0),
      bP: x0 => globalThis.firebase_storage.getStorage(x0),
      bQ: x0 => x0.storageBucket,
      bR: x0 => x0.displayName,
      bS: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      bT: () => globalThis.firebase_firestore.DocumentReference,
      bU: x0 => x0.id,
      c: (c) =>
      queueMicrotask(() => dartInstance.exports.$invokeCallback(c)),
      cB: o => o.byteOffset,
      cC: () => globalThis.window,
      cD: x0 => x0.type,
      cE: (x0,x1) => x0.unregister(x1),
      cF: (x0,x1) => { x0.content = x1 },
      cG: x0 => x0.keyCode,
      cH: (x0,x1) => x0.segment(x1),
      cI: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1,x2) { return wasmFunction(f,arguments.length,x0,x1,x2) }),
      cJ: x0 => x0.ready,
      cK: (x0,x1) => { x0.height = x1 },
      cL: (x0,x1) => ({files: x0,text: x1}),
      cM: (x0,x1) => { x0.transform = x1 },
      cN: (x0,x1) => new ZXing.BrowserMultiFormatReader(x0,x1),
      cO: (x0,x1) => x0.detect(x1),
      cP: x0 => x0.name,
      cQ: x0 => x0.databaseURL,
      cR: x0 => x0.hints,
      cS: (x0,x1) => { x0.display = x1 },
      cT: x0 => x0.path,
      cU: x0 => x0.parent,
      d: (x0,x1) => x0.didCreateEngineInitializer(x1),
      dB: o => o.buffer,
      dC: (o, c) => o instanceof c,
      dD: x0 => x0.maxTouchPoints,
      dE: (x0,x1) => x0.contains(x1),
      dF: (x0,x1) => { x0.name = x1 },
      dG: (x0,x1) => x0.scrollIntoView(x1),
      dH: x0 => x0.index,
      dI: (x0,x1) => x0.forEach(x1),
      dJ: x0 => x0.tracks,
      dK: (x0,x1) => { x0.width = x1 },
      dL: (x0,x1) => ({files: x0,title: x1}),
      dM: x0 => x0.style,
      dN: (x0,x1) => ({width: x0,height: x1}),
      dO: x0 => x0.rawValue,
      dP: x0 => globalThis.firebase_core.getApp(x0),
      dQ: x0 => x0.apiKey,
      dR: x0 => x0.tenantId,
      dS: (x0,x1) => { x0.draggable = x1 },
      dT: x0 => x0.ref,
      dU: x0 => x0.path,
      e: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      eB: Function.prototype.call.bind(DataView.prototype.getUint8),
      eC: (x0,x1) => x0[x1],
      eD: x0 => x0.platform,
      eE: (s) => +s,
      eF: x0 => x0.head,
      eG: x0 => x0.multiViewEnabled,
      eH: x0 => x0.next(),
      eI: x0 => x0.name,
      eJ: x0 => x0.close(),
      eK: x0 => x0.convertToBlob(),
      eL: x0 => ({files: x0}),
      eM: x0 => x0.getVideoTracks(),
      eN: (x0,x1,x2) => ({width: x0,height: x1,facingMode: x2}),
      eO: x0 => x0.format,
      eP: () => globalThis.firebase_core.getApp(),
      eQ: x0 => x0.options,
      eR: x0 => x0.phoneNumber,
      eS: x0 => new firebase_firestore.FieldPath(x0),
      eT: (x0,x1) => x0.get(x1),
      eU: x0 => globalThis.firebase_firestore.doc(x0),
      f: (wasmFunction,f) => finalizeWrapper(f, function() { return wasmFunction(f,arguments.length) }),
      fB: (b, o) => new DataView(b, o),
      fC: x0 => x0.length,
      fD: x0 => x0.body,
      fE: s => {
        if (!/^\s*[+-]?(?:Infinity|NaN|(?:\.\d+|\d+(?:\.\d*)?)(?:[eE][+-]?\d+)?)\s*$/.test(s)) {
          return NaN;
        }
        return parseFloat(s);
      },
      fF: (x0,x1) => x0.removeChild(x1),
      fG: (x0,x1) => x0.replaceWith(x1),
      fH: x0 => x0.value,
      fI: x0 => x0.statusText,
      fJ: (x0,x1) => ({frameIndex: x0,completeFramesOnly: x1}),
      fK: (x0,x1,x2) => new ImageData(x0,x1,x2),
      fL: (x0,x1) => ({title: x0,text: x1}),
      fM: x0 => x0.getSettings(),
      fN: x0 => x0.facingMode,
      fO: x0 => x0.y,
      fP: x0 => x0.state,
      fQ: () => globalThis.firebase_core.SDK_VERSION,
      fR: x0 => x0.email,
      fS: (x0,x1) => new firebase_firestore.FieldPath(x0,x1),
      fT: x0 => x0.id,
      fU: (x0,x1) => globalThis.firebase_firestore.collection(x0,x1),
      g: (x0,x1) => ({initializeEngine: x0,autoStart: x1}),
      gB: (b, o, l) => new DataView(b, o, l),
      gC: (string, token) => string.split(token),
      gD: () => globalThis.document,
      gE: s => s.trim(),
      gF: x0 => x0.firstChild,
      gG: (x0,x1) => { x0.type = x1 },
      gH: x0 => x0.done,
      gI: x0 => x0.url,
      gJ: (x0,x1) => x0.decode(x1),
      gK: (x0,x1) => x0.getContext(x1),
      gL: () => ({}),
      gM: x0 => x0.facingMode,
      gN: x0 => x0.height,
      gO: x0 => x0.x,
      gP: x0 => x0.snapshot,
      gQ: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      gR: (x0,x1) => globalThis.firebase_auth.getMultiFactorResolver(x0,x1),
      gS: (x0,x1,x2) => new firebase_firestore.FieldPath(x0,x1,x2),
      gT: (x0,x1) => globalThis.firebase_firestore.getFirestore(x0,x1),
      gU: x0 => x0.length,
      h: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      hB: Function.prototype.call.bind(DataView.prototype.getFloat64),
      hC: o => o instanceof Array,
      hD: (x0,x1,x2) => x0.addEventListener(x1,x2),
      hE: x0 => x0.classList,
      hF: x0 => x0.viewConstraints,
      hG: (x0,x1) => { x0.className = x1 },
      hH: (o, m, a) => o[m].apply(o, a),
      hI: x0 => x0.status,
      hJ: x0 => x0.displayHeight,
      hK: (x0,x1) => new OffscreenCanvas(x0,x1),
      hL: x0 => globalThis.pdfjsLib.getDocument(x0),
      hM: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      hN: x0 => x0.width,
      hO: x0 => x0.cornerPoints,
      hP: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      hQ: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      hR: x0 => x0.customData,
      hS: (x0,x1,x2,x3) => new firebase_firestore.FieldPath(x0,x1,x2,x3),
      hT: (x0,x1,x2,x3) => x0.set(x1,x2,x3),
      hU: x0 => x0.getReader(),
      i: x0 => new Promise(x0),
      iB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Float64Array) return 1;
        return 2;
      },
      iC: (a, i) => a[i],
      iD: x0 => x0.hasFocus(),
      iE: x0 => x0.preventDefault(),
      iF: x0 => x0.hostElement,
      iG: (x0,x1) => { x0.tabIndex = x1 },
      iH: x0 => x0.iterator,
      iI: x0 => x0.getReader(),
      iJ: x0 => x0.displayWidth,
      iK: x0 => x0.allocationSize(),
      iL: (x0,x1) => x0.createElement(x1),
      iM: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      iN: x0 => x0.attachStreamToVideo,
      iO: x0 => globalThis.URL.revokeObjectURL(x0),
      iP: (x0,x1) => x0.then(x1),
      iQ: (x0,x1) => ({createScript: x0,createScriptURL: x1}),
      iR: x0 => x0.message,
      iS: (x0,x1,x2,x3,x4) => new firebase_firestore.FieldPath(x0,x1,x2,x3,x4),
      iT: (x0,x1,x2) => x0.set(x1,x2),
      iU: x0 => x0.value,
      j: (x0,x1,x2) => x0.call(x1,x2),
      jB: Function.prototype.call.bind(DataView.prototype.setFloat64),
      jC: a => a.length,
      jD: x0 => x0.relatedTarget,
      jE: x0 => x0.parent,
      jF: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      jG: (x0,x1) => { x0.name = x1 },
      jH: () => globalThis.Symbol,
      jI: x0 => x0.read(),
      jJ: x0 => x0.duration,
      jK: (x0,x1) => x0.copyTo(x1),
      jL: (x0,x1) => x0.getContext(x1),
      jM: (x0,x1) => { x0.onpause = x1 },
      jN: () => new Map(),
      jO: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      jP: (x0,x1,x2) => globalThis.firebase_storage.uploadBytesResumable(x0,x1,x2),
      jQ: (x0,x1) => x0.createScriptURL(x1),
      jR: x0 => x0.code,
      jS: (x0,x1,x2,x3,x4,x5) => new firebase_firestore.FieldPath(x0,x1,x2,x3,x4,x5),
      jT: (x0,x1) => x0.delete(x1),
      jU: x0 => x0.done,
      k: (constructor, args) => {
        const factoryFunction = constructor.bind.apply(
            constructor, [null, ...args]);
        return new factoryFunction();
      },
      kB: (t, s) => t.set(s),
      kC: (x0,x1) => x0.test(x1),
      kD: x0 => x0.shiftKey,
      kE: x0 => x0.timeStamp,
      kF: x0 => ({runApp: x0}),
      kG: (x0,x1) => { x0.placeholder = x1 },
      kH: (x0,x1) => new Intl.Segmenter(x0,x1),
      kI: x0 => x0.value,
      kJ: x0 => x0.image,
      kK: (x0,x1) => { x0.height = x1 },
      kL: (x0,x1) => x0.getPage(x1),
      kM: (x0,x1) => { x0.onplay = x1 },
      kN: (x0,x1,x2) => x0.set(x1,x2),
      kO: (x0,x1,x2,x3) => x0.toBlob(x1,x2,x3),
      kP: () => ({}),
      kQ: (x0,x1,x2) => x0.createScript(x1,x2),
      kR: x0 => globalThis.firebase_auth.getRedirectResult(x0),
      kS: (x0,x1,x2,x3,x4,x5,x6) => new firebase_firestore.FieldPath(x0,x1,x2,x3,x4,x5,x6),
      kT: x0 => x0.commit(),
      kU: x0 => x0.read(),
      l: x0 => new Array(x0),
      lB: Function.prototype.call.bind(DataView.prototype.setFloat32),
      lC: x0 => x0.userAgent,
      lD: (decoder, codeUnits) => decoder.decode(codeUnits),
      lE: (x0,x1) => x0.hasAttribute(x1),
      lF: Function.prototype.call.bind(DataView.prototype.getBigInt64),
      lG: (x0,x1) => { x0.autocomplete = x1 },
      lH: x0 => x0.Segmenter,
      lI: x0 => x0.done,
      lJ: () => globalThis.window.ImageDecoder,
      lK: (x0,x1) => { x0.width = x1 },
      lL: (x0,x1) => x0.getViewport(x1),
      lM: (x0,x1) => { x0.controls = x1 },
      lN: (x0,x1) => x0.querySelector(x1),
      lO: x0 => x0.size,
      lP: (x0,x1) => { x0.customMetadata = x1 },
      lQ: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      lR: (x0,x1,x2) => ({errorMap: x0,persistence: x1,popupRedirectResolver: x2}),
      lS: (x0,x1,x2,x3,x4,x5,x6,x7) => new firebase_firestore.FieldPath(x0,x1,x2,x3,x4,x5,x6,x7),
      lT: x0 => globalThis.firebase_firestore.writeBatch(x0),
      lU: x0 => x0.assetBase,
      m: o => [o],
      mB: Function.prototype.call.bind(DataView.prototype.getFloat32),
      mC: x0 => x0.navigator,
      mD: () => new TextDecoder("utf-8", {fatal: true}),
      mE: x0 => x0.buttons,
      mF: Function.prototype.call.bind(DataView.prototype.setBigInt64),
      mG: (x0,x1) => { x0.name = x1 },
      mH: x0 => x0.buffer,
      mI: x0 => x0.cancel(),
      mJ: x0 => x0.status,
      mK: (x0,x1) => x0.toDataURL(x1),
      mL: (x0,x1) => x0.render(x1),
      mM: (x0,x1) => { x0.pointerEvents = x1 },
      mN: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      mO: (x0,x1,x2,x3,x4,x5) => x0.drawImage(x1,x2,x3,x4,x5),
      mP: (x0,x1) => { x0.contentType = x1 },
      mQ: (o, p) => delete o[p],
      mR: (x0,x1) => globalThis.firebase_auth.initializeAuth(x0,x1),
      mS: (x0,x1,x2,x3,x4,x5,x6,x7,x8) => new firebase_firestore.FieldPath(x0,x1,x2,x3,x4,x5,x6,x7,x8),
      mT: () => globalThis.firebase_firestore.count(),
      mU: x0 => x0.loader,
      n: (o0, o1) => [o0, o1],
      nB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Float32Array) return 1;
        return 2;
      },
      nC: Function.prototype.call.bind(String.prototype.toLowerCase),
      nD: () => new TextDecoder("utf-8", {fatal: false}),
      nE: x0 => x0.ctrlKey,
      nF: (o, start, length) => new BigInt64Array(o.buffer, o.byteOffset + start, length),
      nG: (x0,x1) => { x0.placeholder = x1 },
      nH: x0 => x0.wasmMemory,
      nI: x0 => x0.body,
      nJ: x0 => x0.response,
      nK: (x0,x1,x2,x3) => x0.drawImage(x1,x2,x3),
      nL: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      nM: (x0,x1) => { x0.transformOrigin = x1 },
      nN: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      nO: x0 => x0.height,
      nP: x0 => globalThis.firebase_storage.getDownloadURL(x0),
      nQ: (o, p, v) => o[p] = v,
      nR: () => globalThis.firebase_auth.browserPopupRedirectResolver,
      nS: (x0,x1,x2,x3,x4,x5,x6,x7,x8,x9) => new firebase_firestore.FieldPath(x0,x1,x2,x3,x4,x5,x6,x7,x8,x9),
      nT: x0 => globalThis.firebase_firestore.sum(x0),
      nU: () => globalThis._flutter,
      o: (o0, o1, o2) => [o0, o1, o2],
      oB: Function.prototype.call.bind(DataView.prototype.getUint32),
      oC: Object.is,
      oD: (a, i, v) => a[i] = v,
      oE: x0 => x0.y,
      oF: (x0,x1,x2,x3) => x0.pushState(x1,x2,x3),
      oG: (x0,x1) => { x0.action = x1 },
      oH: () => globalThis.window._flutter_skwasmInstance,
      oI: x0 => x0.headers,
      oJ: (x0,x1,x2) => x0.setRequestHeader(x1,x2),
      oK: (x0,x1) => x0.getContext(x1),
      oL: (x0,x1) => x0.toBlob(x1),
      oM: (x0,x1) => { x0.objectFit = x1 },
      oN: (x0,x1) => x0.appendChild(x1),
      oO: x0 => x0.width,
      oP: (x0,x1,x2) => globalThis.firebase_core.registerVersion(x0,x1,x2),
      oQ: (x0,x1) => { x0.text = x1 },
      oR: () => globalThis.firebase_auth.debugErrorMap,
      oS: () => globalThis.firebase_firestore.documentId(),
      oT: x0 => globalThis.firebase_firestore.average(x0),
      p: (o0, o1, o2, o3) => [o0, o1, o2, o3],
      pB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Uint32Array) return 1;
        return 2;
      },
      pC: x0 => x0.vendor,
      pD: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI8ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      pE: x0 => x0.x,
      pF: x0 => x0.history,
      pG: (x0,x1) => { x0.method = x1 },
      pH: () => new TextDecoder(),
      pI: x0 => x0.signal,
      pJ: (x0,x1) => { x0.responseType = x1 },
      pK: x0 => x0.format,
      pL: x0 => x0.cleanup(),
      pM: (x0,x1) => { x0.width = x1 },
      pN: x0 => x0.head,
      pO: (x0,x1) => { x0.src = x1 },
      pP: x0 => x0.sessionStorage,
      pQ: (x0,x1) => { x0.text = x1 },
      pR: () => globalThis.firebase_auth.browserSessionPersistence,
      pS: (x0,x1) => new firebase_firestore.Timestamp(x0,x1),
      pT: (x0,x1) => globalThis.firebase_firestore.getAggregateFromServer(x0,x1),
      q: (x0,x1,x2) => { x0[x1] = x2 },
      qB: Function.prototype.call.bind(DataView.prototype.getInt32),
      qC: (x0,x1) => x0.createTextNode(x1),
      qD: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI16ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      qE: x0 => x0.scrollTop,
      qF: (x0,x1,x2,x3) => x0.replaceState(x1,x2,x3),
      qG: (x0,x1) => { x0.noValidate = x1 },
      qH: x0 => x0.debugSkipFontRetryDelay,
      qI: () => {
        return typeof process != "undefined" &&
               Object.prototype.toString.call(process) == "[object process]" &&
               process.platform == "win32"
      },
      qJ: () => new XMLHttpRequest(),
      qK: x0 => x0.getRegistration(),
      qL: x0 => x0.destroy(),
      qM: (x0,x1) => { x0.height = x1 },
      qN: (x0,x1) => { x0.onerror = x1 },
      qO: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      qP: (x0,x1) => { x0.fetchTimeoutMillis = x1 },
      qQ: x0 => x0.trustedTypes,
      qR: () => globalThis.firebase_auth.browserLocalPersistence,
      qS: (x0,x1) => new firebase_firestore.GeoPoint(x0,x1),
      qT: x0 => x0.data(),
      r: (o, p) => o[p],
      rB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Int32Array) return 1;
        return 2;
      },
      rC: (x0,x1) => { x0.id = x1 },
      rD: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI32ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      rE: x0 => x0.offsetTop,
      rF: o => {
        const proto = Object.getPrototypeOf(o);
        return proto === Object.prototype || proto === null;
      },
      rG: (x0,x1) => x0.removeAttribute(x1),
      rH: (x0,x1,x2) => x0.set(x1,x2),
      rI: () => {
        // On browsers return `globalThis.location.href`
        if (globalThis.location != null) {
          return globalThis.location.href;
        }
        return null;
      },
      rJ: (x0,x1) => x0.get(x1),
      rK: (x0,x1) => x0.register(x1),
      rL: x0 => x0.height,
      rM: x0 => x0.getSupportedConstraints(),
      rN: (x0,x1) => x0.removeChild(x1),
      rO: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      rP: (x0,x1) => { x0.minimumFetchIntervalMillis = x1 },
      rQ: (o, t) => typeof o === t,
      rR: () => globalThis.firebase_auth.indexedDBLocalPersistence,
      rS: x0 => globalThis.firebase_firestore.vector(x0),
      rT: (x0,x1,x2) => globalThis.firebase_firestore.where(x0,x1,x2),
      s: () => globalThis,
      sB: o => o instanceof Uint16Array,
      sC: (x0,x1) => { x0.nonce = x1 },
      sD: x0 => x0.visibilityState,
      sE: x0 => x0.scrollLeft,
      sF: o => Object.keys(o),
      sG: x0 => x0.isConnected,
      sH: x0 => x0.fontFallbackBaseUrl,
      sI: (x0,x1) => globalThis.updateWebBranding(x0,x1),
      sJ: x0 => x0.body,
      sK: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      sL: x0 => x0.width,
      sM: x0 => ({ideal: x0}),
      sN: (x0,x1) => { x0.onload = x1 },
      sO: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      sP: x0 => x0.settings,
      sQ: (x0,x1) => x0.getIdToken(x1),
      sR: x0 => x0.tenantId,
      sS: x0 => globalThis.firebase_firestore.Bytes.fromUint8Array(x0),
      sT: (x0,x1) => globalThis.firebase_firestore.query(x0,x1),
      t: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      tB: Function.prototype.call.bind(DataView.prototype.getUint16),
      tC: x0 => x0.nonce,
      tD: (x0,x1,x2) => x0.removeEventListener(x1,x2),
      tE: x0 => x0.offsetLeft,
      tF: x0 => x0.state,
      tG: x0 => x0.click(),
      tH: (handle) => clearInterval(handle),
      tI: x0 => globalThis.updateWebFavicon(x0),
      tJ: x0 => x0.headers,
      tK: (x0,x1) => { x0.onmessage = x1 },
      tL: x0 => x0.promise,
      tM: (x0,x1,x2) => ({width: x0,height: x1,deviceId: x2}),
      tN: (x0,x1) => { x0.src = x1 },
      tO: (x0,x1) => { x0.oncancel = x1 },
      tP: x0 => globalThis.firebase_remote_config.getRemoteConfig(x0),
      tQ: x0 => x0.providerId,
      tR: x0 => x0.signOut(),
      tS: (x0,x1) => globalThis.firebase_firestore.doc(x0,x1),
      tT: () => globalThis.firebase_firestore.and,
      u: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      uB: o => o instanceof Int16Array,
      uC: () => globalThis.window.flutterConfiguration,
      uD: x0 => x0.disconnect(),
      uE: x0 => x0.offsetParent,
      uF: x0 => x0.state,
      uG: (x0,x1) => x0.getElementsByClassName(x1),
      uH: (ms, c) =>
      setInterval(() => dartInstance.exports.$invokeCallback(c), ms),
      uI: x0 => x0.naturalHeight,
      uJ: x0 => x0.close(),
      uK: x0 => x0.payload,
      uL: (x0,x1) => { x0.viewport = x1 },
      uM: x0 => ({video: x0}),
      uN: (x0,x1) => { x0.crossOrigin = x1 },
      uO: (x0,x1) => { x0.onchange = x1 },
      uP: (x0,x1) => { x0.defaultConfig = x1 },
      uQ: x0 => x0.uid,
      uR: (x0,x1) => globalThis.firebase_auth.signInWithPopup(x0,x1),
      uS: (x0,x1,x2) => globalThis.firebase_firestore.setDoc(x0,x1,x2),
      uT: () => globalThis.firebase_firestore.or,
      v: (x0,x1) => ({addView: x0,removeView: x1}),
      vB: Function.prototype.call.bind(DataView.prototype.getInt16),
      vC: (x0,x1) => x0.attachShadow(x1),
      vD: x0 => new Intl.Locale(x0),
      vE: (o, p, r) => o.replace(p, () => r),
      vF: (x0,x1) => x0.go(x1),
      vG: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmF32ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      vH: () => Date.now(),
      vI: x0 => x0.naturalWidth,
      vJ: x0 => x0.tag,
      vK: x0 => x0.reply,
      vL: (x0,x1) => { x0.canvasContext = x1 },
      vM: (x0,x1) => ({width: x0,height: x1}),
      vN: (x0,x1) => { x0.lang = x1 },
      vO: x0 => x0.type,
      vP: x0 => globalThis.firebase_remote_config.fetchAndActivate(x0),
      vQ: x0 => x0.providerData,
      vR: (x0,x1) => x0.setCustomParameters(x1),
      vS: (x0,x1) => globalThis.firebase_firestore.setDoc(x0,x1),
      vT: x0 => globalThis.firebase_firestore.limitToLast(x0),
      w: (l, r) => l === r,
      wB: o => o instanceof Uint8ClampedArray,
      wC: (x0,x1) => x0.createElement(x1),
      wD: x0 => x0.region,
      wE: (o, p, r) => o.replaceAll(p, () => r),
      wF: x0 => x0.hash,
      wG: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmF64ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      wH: (x0,x1,x2) => x0.insertBefore(x1,x2),
      wI: (x0,x1) => x0.createElement(x1),
      wJ: x0 => x0.getNotifications(),
      wK: x0 => x0.id,
      wL: (x0,x1) => { x0.width = x1 },
      wM: (x0,x1,x2) => ({width: x0,height: x1,facingMode: x2}),
      wN: (x0,x1) => { x0.type = x1 },
      wO: x0 => x0.lastModified,
      wP: (x0,x1) => globalThis.firebase_remote_config.getBoolean(x0,x1),
      wQ: x0 => x0.tenantId,
      wR: (x0,x1) => x0.addScope(x1),
      wS: (wasmFunction,f) => finalizeWrapper(f, function() { return wasmFunction(f,arguments.length) }),
      wT: x0 => globalThis.firebase_firestore.limit(x0),
      x: x0 => x0.random(),
      xB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Uint8Array) return 1;
        return 2;
      },
      xC: x0 => x0.scale,
      xD: x0 => x0.script,
      xE: x0 => x0.deltaMode,
      xF: x0 => x0.location,
      xG: (x0,x1) => x0.dispatchEvent(x1),
      xH: x0 => x0.id,
      xI: (x0,x1) => { x0.pointerEvents = x1 },
      xJ: (x0,x1,x2) => x0.showNotification(x1,x2),
      xK: x0 => x0.action,
      xL: x0 => x0.width,
      xM: (x0,x1) => x0.getUserMedia(x1),
      xN: (x0,x1) => { x0.defer = x1 },
      xO: x0 => x0.name,
      xP: (x0,x1) => globalThis.firebase_remote_config.getString(x0,x1),
      xQ: x0 => x0.refreshToken,
      xR: () => new firebase_auth.GoogleAuthProvider(),
      xS: x0 => globalThis.firebase_firestore.increment(x0),
      xT: () => globalThis.firebase_firestore.endBefore,
      y: () => globalThis.Math,
      yB: Function.prototype.call.bind(DataView.prototype.setInt32),
      yC: x0 => x0.visualViewport,
      yD: x0 => x0.language,
      yE: x0 => x0.deltaY,
      yF: x0 => x0.search,
      yG: (x0,x1) => x0.createEvent(x1),
      yH: x0 => x0.offsetHeight,
      yI: (x0,x1) => { x0.height = x1 },
      yJ: (x0,x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11,x12) => ({dir: x0,lang: x1,body: x2,tag: x3,image: x4,icon: x5,badge: x6,timestamp: x7,renotify: x8,silent: x9,requireInteraction: x10,data: x11,actions: x12}),
      yK: x0 => x0.data,
      yL: (x0,x1) => { x0.height = x1 },
      yM: x0 => x0.deviceId,
      yN: (x0,x1) => { x0.async = x1 },
      yO: (x0,x1) => x0.item(x1),
      yP: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      yQ: x0 => x0.photoURL,
      yR: (x0,x1) => globalThis.firebase_auth.signInWithRedirect(x0,x1),
      yS: () => globalThis.firebase_firestore.arrayUnion,
      yT: () => globalThis.firebase_firestore.endAt,
      z: (x0,x1) => x0.prepend(x1),
      zB: Function.prototype.call.bind(DataView.prototype.setUint32),
      zC: x0 => x0.devicePixelRatio,
      zD: x0 => x0.languages,
      zE: x0 => x0.deltaX,
      zF: x0 => x0.pathname,
      zG: (x0,x1,x2,x3) => x0.initEvent(x1,x2,x3),
      zH: x0 => x0.offsetWidth,
      zI: (x0,x1) => { x0.width = x1 },
      zJ: x0 => x0.active,
      zK: x0 => x0.serviceWorker,
      zL: x0 => x0.height,
      zM: x0 => x0.getCapabilities(),
      zN: (x0,x1) => { x0.id = x1 },
      zO: x0 => x0.length,
      zP: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      zQ: x0 => x0.phoneNumber,
      zR: x0 => x0.call(),
      zS: () => globalThis.firebase_firestore.serverTimestamp(),
      zT: () => globalThis.firebase_firestore.startAfter,

    };

    const baseImports = {
      _: dart2wasm,
      Math: Math,
      Date: Date,
      Object: Object,
      Array: Array,
      Reflect: Reflect,
      WebAssembly: {
        JSTag: WebAssembly.JSTag,
      },
      "": new Proxy({}, { get(_, prop) { return prop; } }),

    };

    const jsStringPolyfill = {
      "charCodeAt": (s, i) => s.charCodeAt(i),
      "compare": (s1, s2) => {
        if (s1 < s2) return -1;
        if (s1 > s2) return 1;
        return 0;
      },
      "concat": (s1, s2) => s1 + s2,
      "equals": (s1, s2) => s1 === s2,
      "fromCharCode": (i) => String.fromCharCode(i),
      "length": (s) => s.length,
      "substring": (s, a, b) => s.substring(a, b),
      "fromCharCodeArray": (a, start, end) => {
        if (end <= start) return '';

        const read = dartInstance.exports.$wasmI16ArrayGet;
        let result = '';
        let index = start;
        const chunkLength = Math.min(end - index, 500);
        let array = new Array(chunkLength);
        while (index < end) {
          const newChunkLength = Math.min(end - index, 500);
          for (let i = 0; i < newChunkLength; i++) {
            array[i] = read(a, index++);
          }
          if (newChunkLength < chunkLength) {
            array = array.slice(0, newChunkLength);
          }
          result += String.fromCharCode(...array);
        }
        return result;
      },
      "intoCharCodeArray": (s, a, start) => {
        if (s === '') return 0;

        const write = dartInstance.exports.$wasmI16ArraySet;
        for (var i = 0; i < s.length; ++i) {
          write(a, start++, s.charCodeAt(i));
        }
        return s.length;
      },
      "test": (s) => typeof s == "string",
    };


    

    dartInstance = await WebAssembly.instantiate(this.module, {
      ...baseImports,
      ...additionalImports,
      
      "wasm:js-string": jsStringPolyfill,
    });

    return new InstantiatedApp(this, dartInstance);
  }
}

class InstantiatedApp {
  constructor(compiledApp, instantiatedModule) {
    this.compiledApp = compiledApp;
    this.instantiatedModule = instantiatedModule;
  }

  // Call the main function with the given arguments.
  invokeMain(...args) {
    this.instantiatedModule.exports.$invokeMain(args);
  }
}
