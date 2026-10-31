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
      AJ: () => globalThis.document,
      AK: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      AL: (x0,x1) => x0.append(x1),
      AM: (x0,x1) => { x0.href = x1 },
      AN: (x0,x1) => { x0.transform = x1 },
      AO: (x0,x1) => ({width: x0,height: x1}),
      AP: x0 => x0.rawValue,
      AQ: x0 => globalThis.firebase_core.getApp(x0),
      AR: x0 => x0.databaseURL,
      AS: x0 => x0.phoneNumber,
      AT: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      AU: x0 => globalThis.firebase_firestore.writeBatch(x0),
      AV: x0 => x0.done,
      B: s => printToConsole(s),
      BB: b => !!b,
      BC: Function.prototype.call.bind(DataView.prototype.setUint16),
      BD: x0 => x0.width,
      BE: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      BF: x0 => x0.wheelDeltaX,
      BG: (x0,x1) => x0.querySelectorAll(x1),
      BH: x0 => x0.clipboard,
      BI: x0 => x0.disabled,
      BJ: x0 => x0.src,
      BK: (x0,x1,x2,x3) => x0.removeEventListener(x1,x2,x3),
      BL: (x0,x1,x2) => x0.insertRule(x1,x2),
      BM: () => globalThis.document,
      BN: x0 => x0.getVideoTracks(),
      BO: (x0,x1,x2) => ({width: x0,height: x1,facingMode: x2}),
      BP: x0 => x0.format,
      BQ: () => globalThis.firebase_core.getApp(),
      BR: x0 => x0.apiKey,
      BS: x0 => x0.lastSignInTime,
      BT: (o,s,v) => o[s] = v,
      BU: () => globalThis.firebase_firestore.count(),
      BV: x0 => x0.read(),
      C: Function.prototype.call.bind(Number.prototype.toString),
      CB: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      CC: Function.prototype.call.bind(DataView.prototype.setUint8),
      CD: x0 => x0.screen,
      CE: x0 => new ResizeObserver(x0),
      CF: x0 => x0.key,
      CG: (x0,x1) => x0.requestAnimationFrame(x1),
      CH: (x0,x1) => x0.writeText(x1),
      CI: (x0,x1) => { x0.min = x1 },
      CJ: x0 => x0.decode(),
      CK: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      CL: (x0,x1) => x0.add(x1),
      CM: (x0,x1,x2) => ({files: x0,title: x1,text: x2}),
      CN: x0 => x0.getSettings(),
      CO: x0 => x0.facingMode,
      CP: x0 => x0.y,
      CQ: x0 => x0.state,
      CR: x0 => x0.options,
      CS: x0 => x0.creationTime,
      CT: () => Symbol("jsBoxedDartObjectProperty"),
      CU: x0 => globalThis.firebase_firestore.sum(x0),
      CV: x0 => x0.assetBase,
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
      DJ: (x0,x1,x2,x3) => x0.open(x1,x2,x3),
      DK: () => new XMLHttpRequest(),
      DL: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      DM: (x0,x1) => ({files: x0,text: x1}),
      DN: x0 => x0.facingMode,
      DO: x0 => x0.height,
      DP: x0 => x0.x,
      DQ: x0 => x0.snapshot,
      DR: () => globalThis.firebase_core.SDK_VERSION,
      DS: x0 => x0.metadata,
      DT: (x0,x1) => new firebase_firestore.Timestamp(x0,x1),
      DU: x0 => globalThis.firebase_firestore.average(x0),
      DV: x0 => x0.loader,
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
      EJ: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      EK: (x0,x1,x2,x3) => x0.open(x1,x2,x3),
      EL: x0 => x0.preventDefault(),
      EM: (x0,x1) => ({files: x0,title: x1}),
      EN: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      EO: x0 => x0.width,
      EP: x0 => x0.cornerPoints,
      EQ: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      ER: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      ES: x0 => x0.isAnonymous,
      ET: (wasmFunction,f) => finalizeWrapper(f, function() { return wasmFunction(f,arguments.length) }),
      EU: (x0,x1) => globalThis.firebase_firestore.getAggregateFromServer(x0,x1),
      EV: () => globalThis._flutter,
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
      FJ: (x0,x1,x2) => x0.addEventListener(x1,x2),
      FK: x0 => x0.send(),
      FL: x0 => x0.createRange(),
      FM: x0 => ({files: x0}),
      FN: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      FO: x0 => x0.attachStreamToVideo,
      FP: x0 => globalThis.URL.revokeObjectURL(x0),
      FQ: (x0,x1) => x0.then(x1),
      FR: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      FS: x0 => x0.emailVerified,
      FT: () => globalThis.firebase_firestore.deleteField(),
      FU: x0 => x0.data(),
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
      GK: x0 => x0.type,
      GL: (x0,x1) => x0.selectNode(x1),
      GM: (x0,x1) => ({title: x0,text: x1}),
      GN: (x0,x1) => { x0.onpause = x1 },
      GO: () => new Map(),
      GP: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      GQ: (x0,x1,x2) => globalThis.firebase_storage.uploadBytesResumable(x0,x1,x2),
      GR: (x0,x1) => ({createScript: x0,createScriptURL: x1}),
      GS: x0 => x0.email,
      GT: () => globalThis.firebase_firestore.serverTimestamp(),
      GU: (x0,x1,x2) => globalThis.firebase_firestore.where(x0,x1,x2),
      H: Function.prototype.call.bind(Number.prototype.toString),
      HB: (a, i) => a.push(i),
      HC: (o, start, length) => new Float32Array(o.buffer, o.byteOffset + start, length),
      HD: x0 => x0.parentNode,
      HE: x0 => x0.computedStyleMap(),
      HF: x0 => x0.tiltX,
      HG: x0 => x0.maxHeight,
      HH: (x0,x1) => { x0.title = x1 },
      HI: (x0,x1) => { x0.disabled = x1 },
      HJ: x0 => x0.send(),
      HK: x0 => x0.response,
      HL: x0 => x0.getSelection(),
      HM: x0 => ({text: x0}),
      HN: (x0,x1) => { x0.onplay = x1 },
      HO: (x0,x1,x2) => x0.set(x1,x2),
      HP: (x0,x1,x2,x3) => x0.toBlob(x1,x2,x3),
      HQ: () => ({}),
      HR: (x0,x1) => x0.createScriptURL(x1),
      HS: x0 => x0.displayName,
      HT: x0 => globalThis.firebase_firestore.increment(x0),
      HU: (x0,x1) => globalThis.firebase_firestore.query(x0,x1),
      I: Function.prototype.call.bind(String.prototype.indexOf),
      IB: x0 => new Int8Array(x0),
      IC: (o, start, length) => new Uint32Array(o.buffer, o.byteOffset + start, length),
      ID: x0 => x0.tagName,
      IE: (x0,x1) => x0.get(x1),
      IF: x0 => x0.pointerType,
      IG: x0 => x0.maxWidth,
      IH: (x0,x1) => x0.vibrate(x1),
      II: (x0,x1) => x0.getRandomValues(x1),
      IJ: (x0,x1) => x0.revokeObjectURL(x1),
      IK: (x0,x1) => { x0.responseType = x1 },
      IL: x0 => x0.removeAllRanges(),
      IM: () => ({}),
      IN: (x0,x1) => { x0.controls = x1 },
      IO: (x0,x1) => x0.querySelector(x1),
      IP: x0 => x0.size,
      IQ: (x0,x1) => { x0.customMetadata = x1 },
      IR: (x0,x1,x2) => x0.createScript(x1,x2),
      IS: x0 => globalThis.firebase_auth.multiFactor(x0),
      IT: x0 => ({serverTimestamps: x0}),
      IU: () => globalThis.firebase_firestore.and,
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
      JJ: (x0,x1) => { x0.src = x1 },
      JK: x0 => x0.vendor,
      JL: (x0,x1) => x0.addRange(x1),
      JM: (x0,x1,x2) => new File(x0,x1,x2),
      JN: (x0,x1) => { x0.pointerEvents = x1 },
      JO: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      JP: (x0,x1,x2,x3,x4,x5) => x0.drawImage(x1,x2,x3,x4,x5),
      JQ: (x0,x1) => { x0.contentType = x1 },
      JR: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      JS: x0 => x0.toJSON(),
      JT: x0 => x0.fromCache,
      JU: () => globalThis.firebase_firestore.or,
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
      KJ: (x0,x1,x2,x3,x4) => globalThis.createImageBitmap(x0,x1,x2,x3,x4),
      KK: x0 => x0.navigator,
      KL: () => globalThis.window,
      KM: (x0,x1) => { x0.type = x1 },
      KN: (x0,x1) => { x0.transformOrigin = x1 },
      KO: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      KP: x0 => x0.height,
      KQ: x0 => globalThis.firebase_storage.getDownloadURL(x0),
      KR: (o, p) => delete o[p],
      KS: x0 => x0.user,
      KT: x0 => x0.hasPendingWrites,
      KU: x0 => globalThis.firebase_firestore.limitToLast(x0),
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
      LJ: x0 => x0.naturalHeight,
      LK: () => globalThis.window,
      LL: (x0,x1) => { x0.innerText = x1 },
      LM: () => ({}),
      LN: (x0,x1) => { x0.objectFit = x1 },
      LO: (x0,x1) => x0.appendChild(x1),
      LP: x0 => x0.width,
      LQ: (x0,x1,x2) => globalThis.firebase_core.registerVersion(x0,x1,x2),
      LR: (o, p, v) => o[p] = v,
      LS: x0 => globalThis.firebase_auth.OAuthProvider.credentialFromResult(x0),
      LT: x0 => x0.metadata,
      LU: x0 => globalThis.firebase_firestore.limit(x0),
      M: x0 => x0.index,
      MB: x0 => new Int16Array(x0),
      MC: (o, start, length) => new Uint8ClampedArray(o.buffer, o.byteOffset + start, length),
      MD: (x0,x1,x2) => x0.setAttribute(x1,x2),
      ME: x0 => x0.matches,
      MF: s => s.trimLeft(),
      MG: (x0,x1) => x0.add(x1),
      MH: (x0,x1) => x0.fetch(x1),
      MI: a => a.pop(),
      MJ: x0 => x0.naturalWidth,
      MK: x0 => new Blob(x0),
      ML: x0 => x0.offsetY,
      MM: x0 => globalThis.pdfjsLib.getDocument(x0),
      MN: (x0,x1) => { x0.width = x1 },
      MO: x0 => x0.head,
      MP: (x0,x1) => { x0.src = x1 },
      MQ: x0 => x0.sessionStorage,
      MR: (x0,x1) => { x0.text = x1 },
      MS: x0 => x0.username,
      MT: x0 => x0.toArray(),
      MU: () => globalThis.firebase_firestore.endBefore,
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
      NJ: x0 => x0.decode(),
      NK: x0 => x0.abort(),
      NL: x0 => x0.offsetX,
      NM: (x0,x1) => x0.getContext(x1),
      NN: (x0,x1) => { x0.height = x1 },
      NO: (x0,x1) => { x0.onerror = x1 },
      NP: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      NQ: (x0,x1) => { x0.fetchTimeoutMillis = x1 },
      NR: (x0,x1) => { x0.text = x1 },
      NS: x0 => x0.providerId,
      NT: x0 => x0.toUint8Array(),
      NU: () => globalThis.firebase_firestore.endAt,
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
      OJ: (x0,x1) => { x0.decoding = x1 },
      OK: (x0,x1,x2,x3) => x0.putImageData(x1,x2,x3),
      OL: x0 => x0.button,
      OM: (x0,x1) => x0.getPage(x1),
      ON: x0 => x0.getSupportedConstraints(),
      OO: (x0,x1) => x0.removeChild(x1),
      OP: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      OQ: (x0,x1) => { x0.minimumFetchIntervalMillis = x1 },
      OR: x0 => x0.trustedTypes,
      OS: x0 => x0.profile,
      OT: () => globalThis.firebase_firestore.Bytes,
      OU: () => globalThis.firebase_firestore.startAfter,
      P: (x0,x1) => x0.exec(x1),
      PB: x0 => new Int32Array(x0),
      PC: (x0,x1) => x0.querySelector(x1),
      PD: s => new Date(s * 1000).getTimezoneOffset() * 60,
      PE: o => typeof o === 'function' && o[jsWrappedDartFunctionSymbol] === true,
      PF: x0 => x0.flags,
      PG: (x0,x1,x2) => x0.setSelectionRange(x1,x2),
      PH: () => typeof dartUseDateNowForTicks !== "undefined",
      PI: () => new WeakMap(),
      PJ: (x0,x1) => { x0.crossOrigin = x1 },
      PK: x0 => x0.arrayBuffer(),
      PL: x0 => x0.classList,
      PM: (x0,x1) => x0.getViewport(x1),
      PN: x0 => ({ideal: x0}),
      PO: (x0,x1) => { x0.onload = x1 },
      PP: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      PQ: x0 => x0.settings,
      PR: (o, t) => typeof o === t,
      PS: x0 => x0.isNewUser,
      PT: () => globalThis.firebase_firestore.VectorValue,
      PU: () => globalThis.firebase_firestore.startAt,
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
      QJ: (x0,x1) => x0.createObjectURL(x1),
      QK: (x0,x1) => x0.transferFromImageBitmap(x1),
      QL: x0 => x0.sheet,
      QM: (x0,x1) => x0.render(x1),
      QN: (x0,x1,x2) => ({width: x0,height: x1,deviceId: x2}),
      QO: (x0,x1) => { x0.src = x1 },
      QP: (x0,x1) => { x0.oncancel = x1 },
      QQ: x0 => globalThis.firebase_remote_config.getRemoteConfig(x0),
      QR: x0 => x0.tenantId,
      QS: x0 => globalThis.firebase_auth.getAdditionalUserInfo(x0),
      QT: x0 => x0.longitude,
      QU: (x0,x1) => globalThis.firebase_firestore.orderBy(x0,x1),
      R: o => o,
      RB: x0 => new Uint32Array(x0),
      RC: x0 => x0.length,
      RD: (handle) => clearTimeout(handle),
      RE: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      RF: (x0,x1) => x0.error(x1),
      RG: (x0,x1,x2) => x0.setSelectionRange(x1,x2),
      RH: () => 1000 * performance.now(),
      RI: x0 => x0.deref(),
      RJ: x0 => x0.URL,
      RK: x0 => x0.height,
      RL: x0 => x0.head,
      RM: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      RN: x0 => ({video: x0}),
      RO: (x0,x1) => { x0.crossOrigin = x1 },
      RP: (x0,x1) => { x0.onchange = x1 },
      RQ: (x0,x1) => { x0.defaultConfig = x1 },
      RR: (x0,x1,x2) => ({errorMap: x0,persistence: x1,popupRedirectResolver: x2}),
      RS: (x0,x1) => globalThis.firebase_auth.signInWithPopup(x0,x1),
      RT: x0 => x0.latitude,
      RU: x0 => x0.metadata,
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
      SJ: x0 => new Blob(x0),
      SK: x0 => x0.width,
      SL: x0 => x0.baseURI,
      SM: (x0,x1) => x0.toBlob(x1),
      SN: (x0,x1) => ({width: x0,height: x1}),
      SO: (x0,x1) => { x0.lang = x1 },
      SP: x0 => x0.type,
      SQ: x0 => globalThis.firebase_remote_config.fetchAndActivate(x0),
      SR: (x0,x1) => globalThis.firebase_auth.initializeAuth(x0,x1),
      SS: (x0,x1) => x0.setCustomParameters(x1),
      ST: () => globalThis.firebase_firestore.GeoPoint,
      SU: x0 => x0.doc,
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
      TJ: (x0,x1,x2,x3,x4) => ({type: x0,data: x1,premultiplyAlpha: x2,colorSpaceConversion: x3,preferAnimation: x4}),
      TK: x0 => x0.rasterEndMilliseconds,
      TL: x0 => x0.canvasKitMaximumSurfaces,
      TM: x0 => x0.cleanup(),
      TN: (x0,x1,x2) => ({width: x0,height: x1,facingMode: x2}),
      TO: (x0,x1) => { x0.type = x1 },
      TP: x0 => x0.lastModified,
      TQ: (x0,x1) => globalThis.firebase_remote_config.getNumber(x0,x1),
      TR: () => globalThis.firebase_auth.browserPopupRedirectResolver,
      TS: (x0,x1) => x0.addScope(x1),
      TT: (x0,x1) => x0.data(x1),
      TU: x0 => x0.newIndex,
      U: (string, times) => string.repeat(times),
      UB: x0 => new Float64Array(x0),
      UC: x0 => x0.remove(),
      UD: x0 => x0.top,
      UE: (o, i) => o[i],
      UF: x0 => x0.blur(),
      UG: x0 => x0.value,
      UH: (x0,x1) => x0.decode(x1),
      UI: (a, s, e) => a.slice(s, e),
      UJ: x0 => new window.ImageDecoder(x0),
      UK: x0 => x0.rasterStartMilliseconds,
      UL: x0 => x0.nextSibling,
      UM: x0 => x0.destroy(),
      UN: (x0,x1) => x0.getUserMedia(x1),
      UO: (x0,x1) => { x0.defer = x1 },
      UP: x0 => x0.name,
      UQ: (x0,x1) => globalThis.firebase_remote_config.getBoolean(x0,x1),
      UR: () => globalThis.firebase_auth.debugErrorMap,
      US: () => new firebase_auth.GoogleAuthProvider(),
      UT: x0 => x0.nanoseconds,
      UU: x0 => x0.oldIndex,
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
      VJ: x0 => x0.name,
      VK: x0 => x0.imageBitmaps,
      VL: (x0,x1) => x0.debug(x1),
      VM: x0 => x0.height,
      VN: x0 => x0.deviceId,
      VO: (x0,x1) => { x0.async = x1 },
      VP: (x0,x1) => x0.item(x1),
      VQ: (x0,x1) => globalThis.firebase_remote_config.getString(x0,x1),
      VR: () => globalThis.firebase_auth.browserSessionPersistence,
      VS: x0 => x0.call(),
      VT: x0 => x0.seconds,
      VU: x0 => x0.type,
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
      WJ: x0 => x0.repetitionCount,
      WK: (x0,x1) => { x0.height = x1 },
      WL: x0 => x0.hostElement,
      WM: x0 => x0.width,
      WN: x0 => x0.getCapabilities(),
      WO: (x0,x1) => { x0.id = x1 },
      WP: x0 => x0.length,
      WQ: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      WR: () => globalThis.firebase_auth.browserLocalPersistence,
      WS: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      WT: () => globalThis.firebase_firestore.Timestamp,
      WU: x0 => x0.docChanges(),
      X: x0 => x0.dotAll,
      XB: (x0,x1,x2) => new Uint8Array(x0,x1,x2),
      XC: (x0,x1,x2,x3) => x0.setProperty(x1,x2,x3),
      XD: x0 => x0.clientY,
      XE: x0 => x0.language,
      XF: x0 => x0.innerWidth,
      XG: x0 => x0.selectionEnd,
      XH: x0 => x0.next(),
      XI: x0 => x0.groups,
      XJ: x0 => x0.frameCount,
      XK: (x0,x1) => { x0.width = x1 },
      XL: x0 => x0.location,
      XM: x0 => x0.promise,
      XN: () => ({}),
      XO: x0 => x0.videoHeight,
      XP: x0 => x0.files,
      XQ: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      XR: () => globalThis.firebase_auth.indexedDBLocalPersistence,
      XS: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      XT: x0 => x0.id,
      XU: x0 => x0.docs,
      Y: x0 => x0.unicode,
      YB: (x0,x1,x2) => new DataView(x0,x1,x2),
      YC: x0 => x0.style,
      YD: x0 => x0.clientX,
      YE: (x0,x1,x2,x3) => x0.register(x1,x2,x3),
      YF: x0 => x0.height,
      YG: x0 => x0.value,
      YH: x0 => x0.current(),
      YI: () => new AbortController(),
      YJ: x0 => x0.selectedTrack,
      YK: x0 => x0.convertToBlob(),
      YL: (x0,x1) => x0.getModifierState(x1),
      YM: (x0,x1) => { x0.viewport = x1 },
      YN: (x0,x1) => x0.applyConstraints(x1),
      YO: x0 => x0.videoWidth,
      YP: x0 => x0.target,
      YQ: (x0,x1) => ({next: x0,error: x1}),
      YR: x0 => globalThis.firebase_auth.OAuthProvider.credentialFromError(x0),
      YS: (x0,x1,x2) => x0.onIdTokenChanged(x1,x2),
      YT: () => globalThis.firebase_firestore.DocumentReference,
      YU: (x0,x1) => ({includeMetadataChanges: x0,source: x1}),
      Z: x0 => x0.ignoreCase,
      ZB: (o, p) => o[p],
      ZC: x0 => x0.debugShowSemanticsNodes,
      ZD: x0 => x0.changedTouches,
      ZE: () => globalThis.window.FinalizationRegistry,
      ZF: x0 => x0.width,
      ZG: x0 => x0.selectionDirection,
      ZH: (x0,x1) => new Intl.v8BreakIterator(x0,x1),
      ZI: (x0,x1,x2,x3,x4,x5) => ({method: x0,headers: x1,body: x2,credentials: x3,redirect: x4,signal: x5}),
      ZJ: x0 => x0.completed,
      ZK: (x0,x1,x2) => new ImageData(x0,x1,x2),
      ZL: x0 => x0.metaKey,
      ZM: (x0,x1) => { x0.canvasContext = x1 },
      ZN: (x0,x1) => { x0.whiteBalanceMode = x1 },
      ZO: x0 => x0.stream,
      ZP: (x0,x1) => x0.replaceChildren(x1),
      ZQ: (x0,x1) => globalThis.firebase_messaging.onRegistered(x0,x1),
      ZR: x0 => x0.session,
      ZS: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      ZT: x0 => x0.path,
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
      aJ: x0 => x0.ready,
      aK: (x0,x1) => x0.getContext(x1),
      aL: x0 => x0.altKey,
      aM: (x0,x1) => { x0.width = x1 },
      aN: x0 => x0.whiteBalanceMode,
      aO: x0 => x0.play(),
      aP: (x0,x1) => { x0.accept = x1 },
      aQ: x0 => x0.link,
      aR: x0 => x0.phoneNumber,
      aS: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      aT: x0 => x0.ref,
      aU: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
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
      bJ: x0 => x0.tracks,
      bK: (x0,x1) => new OffscreenCanvas(x0,x1),
      bL: x0 => x0.ctrlKey,
      bM: x0 => x0.width,
      bN: (x0,x1) => { x0.exposureMode = x1 },
      bO: x0 => x0.paused,
      bP: (x0,x1) => { x0.multiple = x1 },
      bQ: x0 => x0.analyticsLabel,
      bR: x0 => x0.uid,
      bS: (x0,x1,x2) => x0.onAuthStateChanged(x1,x2),
      bT: (x0,x1) => x0.get(x1),
      bU: (x0,x1,x2,x3) => globalThis.firebase_firestore.onSnapshot(x0,x1,x2,x3),
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
      cJ: x0 => x0.close(),
      cK: x0 => x0.allocationSize(),
      cL: x0 => x0.isComposing,
      cM: (x0,x1) => { x0.height = x1 },
      cN: x0 => x0.exposureMode,
      cO: (x0,x1,x2,x3) => x0.drawImage(x1,x2,x3),
      cP: (x0,x1) => { x0.type = x1 },
      cQ: x0 => x0.image,
      cR: x0 => x0.enrollmentTime,
      cS: x0 => x0.currentUser,
      cT: x0 => x0.id,
      cU: x0 => globalThis.firebase_firestore.getDocs(x0),
      d: (x0,x1) => x0.didCreateEngineInitializer(x1),
      dB: o => o.buffer,
      dC: (o, c) => o instanceof c,
      dD: x0 => x0.maxTouchPoints,
      dE: (x0,x1) => x0.contains(x1),
      dF: (x0,x1) => { x0.name = x1 },
      dG: (x0,x1) => x0.scrollIntoView(x1),
      dH: x0 => x0.index,
      dI: (x0,x1) => x0.forEach(x1),
      dJ: (x0,x1) => ({frameIndex: x0,completeFramesOnly: x1}),
      dK: (x0,x1) => x0.copyTo(x1),
      dL: x0 => x0.code,
      dM: x0 => x0.height,
      dN: (x0,x1) => { x0.focusMode = x1 },
      dO: (x0,x1,x2,x3,x4) => x0.getImageData(x1,x2,x3,x4),
      dP: (x0,x1) => x0.getAttribute(x1),
      dQ: x0 => x0.body,
      dR: x0 => x0.factorId,
      dS: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      dT: (x0,x1) => globalThis.firebase_firestore.doc(x0,x1),
      dU: x0 => globalThis.firebase_firestore.getDocsFromServer(x0),
      e: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      eB: Function.prototype.call.bind(DataView.prototype.getUint8),
      eC: (x0,x1) => x0[x1],
      eD: x0 => x0.platform,
      eE: (s) => +s,
      eF: x0 => x0.head,
      eG: x0 => x0.multiViewEnabled,
      eH: x0 => x0.next(),
      eI: x0 => x0.name,
      eJ: (x0,x1) => x0.decode(x1),
      eK: (x0,x1) => { x0.height = x1 },
      eL: x0 => x0.repeat,
      eM: (x0,x1) => { x0.scale = x1 },
      eN: x0 => x0.focusMode,
      eO: (x0,x1,x2) => x0.readBarcodes(x1,x2),
      eP: (x0,x1) => x0.debug(x1),
      eQ: x0 => x0.title,
      eR: x0 => x0.displayName,
      eS: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      eT: x0 => new firebase_firestore.FieldPath(x0),
      eU: x0 => globalThis.firebase_firestore.getDocsFromCache(x0),
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
      fJ: x0 => x0.displayHeight,
      fK: (x0,x1) => { x0.width = x1 },
      fL: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      fM: x0 => x0.document,
      fN: x0 => x0.enumerateDevices(),
      fO: x0 => x0.text,
      fP: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      fQ: x0 => x0.fcmOptions,
      fR: x0 => x0.hints,
      fS: x0 => x0.hostname,
      fT: (x0,x1) => new firebase_firestore.FieldPath(x0,x1),
      fU: x0 => x0.source,
      g: (x0,x1) => ({initializeEngine: x0,autoStart: x1}),
      gB: (b, o, l) => new DataView(b, o, l),
      gC: (string, token) => string.split(token),
      gD: () => globalThis.document,
      gE: s => s.trim(),
      gF: x0 => x0.firstChild,
      gG: (x0,x1) => { x0.type = x1 },
      gH: x0 => x0.done,
      gI: x0 => x0.url,
      gJ: x0 => x0.displayWidth,
      gK: (x0,x1) => x0.toDataURL(x1),
      gL: x0 => x0.userAgent,
      gM: x0 => x0.numPages,
      gN: x0 => x0.deviceId,
      gO: x0 => x0.format,
      gP: x0 => ({createScriptURL: x0}),
      gQ: x0 => x0.notification,
      gR: x0 => x0.tenantId,
      gS: x0 => x0.location,
      gT: (x0,x1,x2) => new firebase_firestore.FieldPath(x0,x1,x2),
      gU: x0 => ({source: x0}),
      h: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      hB: Function.prototype.call.bind(DataView.prototype.getFloat64),
      hC: o => o instanceof Array,
      hD: (x0,x1,x2) => x0.addEventListener(x1,x2),
      hE: x0 => x0.classList,
      hF: x0 => x0.viewConstraints,
      hG: (x0,x1) => { x0.className = x1 },
      hH: (o, m, a) => o[m].apply(o, a),
      hI: x0 => x0.status,
      hJ: x0 => x0.duration,
      hK: (x0,x1,x2,x3) => x0.drawImage(x1,x2,x3),
      hL: (x0,x1,x2,x3) => x0.open(x1,x2,x3),
      hM: x0 => x0.promise,
      hN: x0 => x0.kind,
      hO: x0 => x0.bytes,
      hP: (x0,x1,x2) => x0.createPolicy(x1,x2),
      hQ: x0 => x0.messageId,
      hR: x0 => x0.phoneNumber,
      hS: x0 => x0.token,
      hT: (x0,x1,x2,x3) => new firebase_firestore.FieldPath(x0,x1,x2,x3),
      hU: (x0,x1) => globalThis.firebase_firestore.collectionGroup(x0,x1),
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
      iJ: x0 => x0.image,
      iK: (x0,x1) => x0.getContext(x1),
      iL: (x0,x1) => x0.getItem(x1),
      iM: (x0,x1) => { x0.cMapPacked = x1 },
      iN: x0 => x0.facingMode,
      iO: x0 => x0.y,
      iP: (x0,x1) => x0.createScriptURL(x1),
      iQ: x0 => x0.from,
      iR: x0 => x0.email,
      iS: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      iT: (x0,x1,x2,x3,x4) => new firebase_firestore.FieldPath(x0,x1,x2,x3,x4),
      iU: x0 => globalThis.firebase_firestore.deleteDoc(x0),
      j: (x0,x1,x2) => x0.call(x1,x2),
      jB: Function.prototype.call.bind(DataView.prototype.setFloat64),
      jC: a => a.length,
      jD: x0 => x0.relatedTarget,
      jE: x0 => x0.parent,
      jF: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      jG: (x0,x1) => { x0.name = x1 },
      jH: () => globalThis.Symbol,
      jI: x0 => x0.read(),
      jJ: () => globalThis.window.ImageDecoder,
      jK: x0 => x0.format,
      jL: x0 => x0.localStorage,
      jM: (x0,x1) => { x0.cMapUrl = x1 },
      jN: x0 => x0.mediaDevices,
      jO: x0 => x0.x,
      jP: (x0,x1) => { x0.nonce = x1 },
      jQ: x0 => x0.collapseKey,
      jR: (x0,x1) => globalThis.firebase_auth.getMultiFactorResolver(x0,x1),
      jS: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      jT: (x0,x1,x2,x3,x4,x5) => new firebase_firestore.FieldPath(x0,x1,x2,x3,x4,x5),
      jU: (x0,x1,x2) => globalThis.firebase_firestore.setDoc(x0,x1,x2),
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
      kJ: x0 => x0.status,
      kK: x0 => x0.getRegistration(),
      kL: (x0,x1) => x0.key(x1),
      kM: (x0,x1) => { x0.data = x1 },
      kN: () => globalThis.BarcodeDetector.getSupportedFormats(),
      kO: x0 => x0.bottomLeft,
      kP: (x0,x1) => x0.querySelectorAll(x1),
      kQ: x0 => x0.data,
      kR: x0 => x0.customData,
      kS: (x0,x1,x2) => globalThis.firebase_app_check.onTokenChanged(x0,x1,x2),
      kT: (x0,x1,x2,x3,x4,x5,x6) => new firebase_firestore.FieldPath(x0,x1,x2,x3,x4,x5,x6),
      kU: (x0,x1) => globalThis.firebase_firestore.setDoc(x0,x1),
      l: x0 => new Array(x0),
      lB: Function.prototype.call.bind(DataView.prototype.setFloat32),
      lC: x0 => x0.userAgent,
      lD: (decoder, codeUnits) => decoder.decode(codeUnits),
      lE: (x0,x1) => x0.hasAttribute(x1),
      lF: Function.prototype.call.bind(DataView.prototype.getBigInt64),
      lG: (x0,x1) => { x0.autocomplete = x1 },
      lH: x0 => x0.Segmenter,
      lI: x0 => x0.done,
      lJ: x0 => x0.response,
      lK: (x0,x1) => x0.register(x1),
      lL: x0 => x0.length,
      lM: x0 => ({type: x0}),
      lN: (x0,x1) => x0.call(x1),
      lO: x0 => x0.bottomRight,
      lP: (x0,x1) => x0.item(x1),
      lQ: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      lR: x0 => x0.message,
      lS: x0 => new firebase_app_check.ReCaptchaV3Provider(x0),
      lT: (x0,x1,x2,x3,x4,x5,x6,x7) => new firebase_firestore.FieldPath(x0,x1,x2,x3,x4,x5,x6,x7),
      lU: () => globalThis.firebase_firestore.updateDoc,
      m: o => [o],
      mB: Function.prototype.call.bind(DataView.prototype.getFloat32),
      mC: x0 => x0.navigator,
      mD: () => new TextDecoder("utf-8", {fatal: true}),
      mE: x0 => x0.buttons,
      mF: Function.prototype.call.bind(DataView.prototype.setBigInt64),
      mG: (x0,x1) => { x0.name = x1 },
      mH: x0 => x0.buffer,
      mI: x0 => x0.cancel(),
      mJ: (x0,x1,x2) => x0.setRequestHeader(x1,x2),
      mK: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      mL: (x0,x1) => x0.removeItem(x1),
      mM: (x0,x1) => new Blob(x0,x1),
      mN: x0 => x0.reset,
      mO: x0 => x0.topRight,
      mP: x0 => x0.nonce,
      mQ: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      mR: x0 => x0.code,
      mS: x0 => new firebase_app_check.ReCaptchaEnterpriseProvider(x0),
      mT: (x0,x1,x2,x3,x4,x5,x6,x7,x8) => new firebase_firestore.FieldPath(x0,x1,x2,x3,x4,x5,x6,x7,x8),
      mU: x0 => globalThis.firebase_firestore.getDoc(x0),
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
      nJ: (x0,x1) => { x0.responseType = x1 },
      nK: (x0,x1) => { x0.onmessage = x1 },
      nL: (x0,x1,x2) => x0.setItem(x1,x2),
      nM: x0 => globalThis.URL.createObjectURL(x0),
      nN: x0 => x0.stopContinuousDecode,
      nO: x0 => x0.topLeft,
      nP: x0 => x0.length,
      nQ: (x0,x1) => globalThis.firebase_messaging.onMessage(x0,x1),
      nR: x0 => x0.idToken,
      nS: x0 => ({provider: x0}),
      nT: (x0,x1,x2,x3,x4,x5,x6,x7,x8,x9) => new firebase_firestore.FieldPath(x0,x1,x2,x3,x4,x5,x6,x7,x8,x9),
      nU: x0 => globalThis.firebase_firestore.getDocFromServer(x0),
      o: (o0, o1, o2) => [o0, o1, o2],
      oB: Function.prototype.call.bind(DataView.prototype.getUint32),
      oC: Object.is,
      oD: (a, i, v) => a[i] = v,
      oE: x0 => x0.y,
      oF: (x0,x1,x2,x3) => x0.pushState(x1,x2,x3),
      oG: (x0,x1) => { x0.action = x1 },
      oH: () => globalThis.window._flutter_skwasmInstance,
      oI: x0 => x0.headers,
      oJ: () => new XMLHttpRequest(),
      oK: x0 => x0.payload,
      oL: (x0,x1) => x0.canShare(x1),
      oM: (x0,x1) => x0.append(x1),
      oN: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      oO: x0 => x0.position,
      oP: (x0,x1) => { x0.src = x1 },
      oQ: x0 => globalThis.firebase_messaging.getMessaging(x0),
      oR: x0 => x0.secret,
      oS: (x0,x1) => globalThis.firebase_app_check.initializeAppCheck(x0,x1),
      oT: () => globalThis.firebase_firestore.documentId(),
      oU: x0 => globalThis.firebase_firestore.getDocFromCache(x0),
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
      pJ: (x0,x1) => x0.get(x1),
      pK: x0 => x0.reply,
      pL: (x0,x1) => x0.share(x1),
      pM: (x0,x1) => { x0.target = x1 },
      pN: (x0,x1,x2,x3) => x0.call(x1,x2,x3),
      pO: x0 => x0.isValid,
      pP: x0 => x0.trustedTypes,
      pQ: (x0,x1) => globalThis.firebase_messaging.register(x0,x1),
      pR: x0 => x0.accessToken,
      pS: (x0,x1) => globalThis.firebase_analytics.setAnalyticsCollectionEnabled(x0,x1),
      pT: (x0,x1) => new firebase_firestore.GeoPoint(x0,x1),
      pU: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
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
      qJ: x0 => x0.body,
      qK: x0 => x0.id,
      qL: x0 => x0.message,
      qM: (x0,x1) => x0.getElementById(x1),
      qN: x0 => x0.text,
      qO: (x0,x1,x2,x3) => ({formats: x0,tryHarder: x1,tryRotate: x2,tryInvert: x3}),
      qP: () => globalThis.console,
      qQ: x0 => x0.measurementId,
      qR: x0 => x0.signInMethod,
      qS: (x0,x1) => globalThis.firebase_analytics.initializeAnalytics(x0,x1),
      qT: x0 => globalThis.firebase_firestore.vector(x0),
      qU: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
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
      rJ: x0 => x0.headers,
      rK: x0 => x0.action,
      rL: (x0,x1) => x0.createElement(x1),
      rM: (x0,x1,x2) => x0.setAttribute(x1,x2),
      rN: x0 => x0.barcodeFormat,
      rO: (x0,x1,x2) => ({tryHarder: x0,tryRotate: x1,tryInvert: x2}),
      rP: x0 => x0.trustedTypes,
      rQ: x0 => x0.appId,
      rR: x0 => x0.providerId,
      rS: x0 => x0.firstChild,
      rT: x0 => globalThis.firebase_firestore.Bytes.fromUint8Array(x0),
      rU: (x0,x1,x2) => globalThis.firebase_firestore.onSnapshot(x0,x1,x2),
      s: () => globalThis,
      sB: o => o instanceof Uint16Array,
      sC: (x0,x1) => { x0.nonce = x1 },
      sD: x0 => x0.visibilityState,
      sE: x0 => x0.scrollLeft,
      sF: o => Object.keys(o),
      sG: x0 => x0.isConnected,
      sH: x0 => x0.fontFallbackBaseUrl,
      sI: x0 => x0.naturalHeight,
      sJ: x0 => x0.close(),
      sK: x0 => x0.data,
      sL: x0 => x0.click(),
      sM: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      sN: x0 => x0.rawBytes,
      sO: () => globalThis.ZXingWASM,
      sP: (wasmFunction,f) => finalizeWrapper(f, function() { return wasmFunction(f,arguments.length) }),
      sQ: x0 => x0.messagingSenderId,
      sR: x0 => x0.signOut(),
      sS: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      sT: (x0,x1,x2,x3) => x0.set(x1,x2,x3),
      sU: x0 => x0.id,
      t: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      tB: Function.prototype.call.bind(DataView.prototype.getUint16),
      tC: x0 => x0.nonce,
      tD: (x0,x1,x2) => x0.removeEventListener(x1,x2),
      tE: x0 => x0.offsetLeft,
      tF: x0 => x0.state,
      tG: x0 => x0.click(),
      tH: (handle) => clearInterval(handle),
      tI: x0 => x0.naturalWidth,
      tJ: x0 => x0.tag,
      tK: x0 => x0.serviceWorker,
      tL: x0 => x0.remove(),
      tM: (x0,x1,x2) => x0.addEventListener(x1,x2),
      tN: x0 => x0.y,
      tO: (x0,x1) => { x0.srcObject = x1 },
      tP: x0 => { globalThis.onGoogleLibraryLoad = x0 },
      tQ: x0 => x0.authDomain,
      tR: (x0,x1) => x0.getIdToken(x1),
      tS: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      tT: (x0,x1,x2) => x0.set(x1,x2),
      tU: x0 => x0.parent,
      u: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      uB: o => o instanceof Int16Array,
      uC: () => globalThis.window.flutterConfiguration,
      uD: x0 => x0.disconnect(),
      uE: x0 => x0.offsetParent,
      uF: x0 => x0.state,
      uG: (x0,x1) => x0.getElementsByClassName(x1),
      uH: (ms, c) =>
      setInterval(() => dartInstance.exports.$invokeCallback(c), ms),
      uI: (x0,x1) => x0.createElement(x1),
      uJ: x0 => x0.getNotifications(),
      uK: (x0,x1,x2) => x0.showNotification(x1,x2),
      uL: (o, a) => o + a,
      uM: (x0,x1,x2) => x0.removeEventListener(x1,x2),
      uN: x0 => x0.x,
      uO: x0 => ({willReadFrequently: x0}),
      uP: x0 => x0.code,
      uQ: x0 => x0.projectId,
      uR: x0 => x0.providerId,
      uS: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      uT: x0 => ({merge: x0}),
      uU: x0 => x0.path,
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
      vI: (x0,x1) => { x0.pointerEvents = x1 },
      vJ: o => o.byteLength,
      vK: (x0,x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11,x12) => ({dir: x0,lang: x1,body: x2,tag: x3,image: x4,icon: x5,badge: x6,timestamp: x7,renotify: x8,silent: x9,requireInteraction: x10,data: x11,actions: x12}),
      vL: x0 => x0.children,
      vM: (x0,x1) => { x0.innerHTML = x1 },
      vN: x0 => x0.resultPoints,
      vO: (x0,x1,x2) => x0.getContext(x1,x2),
      vP: (x0,x1) => globalThis.firebase_storage.ref(x0,x1),
      vQ: x0 => x0.name,
      vR: x0 => x0.uid,
      vS: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      vT: (x0,x1) => globalThis.firebase_firestore.getFirestore(x0,x1),
      vU: x0 => globalThis.firebase_firestore.doc(x0),
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
      wI: (x0,x1) => { x0.height = x1 },
      wJ: () => new FileReader(),
      wK: x0 => x0.active,
      wL: x0 => x0.body,
      wM: x0 => x0.permissions,
      wN: x0 => x0.message,
      wO: () => new BarcodeDetector(),
      wP: x0 => x0.name,
      wQ: (x0,x1,x2,x3,x4,x5,x6,x7) => ({apiKey: x0,authDomain: x1,databaseURL: x2,projectId: x3,storageBucket: x4,messagingSenderId: x5,measurementId: x6,appId: x7}),
      wR: x0 => x0.providerData,
      wS: (x0,x1) => { x0.draggable = x1 },
      wT: (x0,x1,x2,x3) => x0.set(x1,x2,x3),
      wU: (x0,x1) => globalThis.firebase_firestore.collection(x0,x1),
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
      xI: (x0,x1) => { x0.width = x1 },
      xJ: (x0,x1) => x0.readAsArrayBuffer(x1),
      xK: () => globalThis.Notification.permission,
      xL: (x0,x1) => { x0.download = x1 },
      xM: x0 => x0.geolocation,
      xN: x0 => x0.videoElement,
      xO: x0 => ({formats: x0}),
      xP: (x0,x1) => globalThis.firebase_storage.getStorage(x0,x1),
      xQ: (x0,x1) => globalThis.firebase_core.initializeApp(x0,x1),
      xR: x0 => x0.tenantId,
      xS: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      xT: (x0,x1,x2) => x0.set(x1,x2),
      xU: x0 => x0.length,
      y: () => globalThis.Math,
      yB: Function.prototype.call.bind(DataView.prototype.setInt32),
      yC: x0 => x0.visualViewport,
      yD: x0 => x0.language,
      yE: x0 => x0.deltaY,
      yF: x0 => x0.search,
      yG: (x0,x1) => x0.createEvent(x1),
      yH: x0 => x0.offsetHeight,
      yI: x0 => x0.style,
      yJ: x0 => x0.result,
      yK: x0 => globalThis.fetch(x0),
      yL: (x0,x1) => { x0.display = x1 },
      yM: x0 => x0.mediaDevices,
      yN: x0 => x0.decodeContinuously,
      yO: x0 => new BarcodeDetector(x0),
      yP: x0 => globalThis.firebase_storage.getStorage(x0),
      yQ: x0 => globalThis.firebase_core.initializeApp(x0),
      yR: x0 => x0.refreshToken,
      yS: x0 => ({maxAttempts: x0}),
      yT: (x0,x1) => x0.delete(x1),
      yU: x0 => x0.getReader(),
      z: (x0,x1) => x0.prepend(x1),
      zB: Function.prototype.call.bind(DataView.prototype.setUint32),
      zC: x0 => x0.devicePixelRatio,
      zD: x0 => x0.languages,
      zE: x0 => x0.deltaX,
      zF: x0 => x0.pathname,
      zG: (x0,x1,x2,x3) => x0.initEvent(x1,x2,x3),
      zH: x0 => x0.offsetWidth,
      zI: (x0,x1) => { x0.src = x1 },
      zJ: (x0,x1,x2,x3) => x0.addEventListener(x1,x2,x3),
      zK: x0 => x0.arrayBuffer(),
      zL: x0 => x0.style,
      zM: x0 => x0.baseURI,
      zN: (x0,x1) => new ZXing.BrowserMultiFormatReader(x0,x1),
      zO: (x0,x1) => x0.detect(x1),
      zP: x0 => x0.name,
      zQ: x0 => x0.storageBucket,
      zR: x0 => x0.photoURL,
      zS: (x0,x1,x2) => globalThis.firebase_firestore.runTransaction(x0,x1,x2),
      zT: x0 => x0.commit(),
      zU: x0 => x0.value,

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
