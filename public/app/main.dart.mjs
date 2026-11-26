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
      AG: x0 => x0.next(),
      AH: (x0,x1,x2) => x0.setSelectionRange(x1,x2),
      AI: x0 => x0.stopPropagation(),
      AJ: (x0,x1) => { x0.decoding = x1 },
      AK: (x0,x1) => { x0.width = x1 },
      AL: x0 => x0.id,
      AM: x0 => x0.localStorage,
      AN: x0 => x0.getVideoTracks(),
      AO: (x0,x1,x2) => ({width: x0,height: x1,facingMode: x2}),
      AP: x0 => x0.y,
      AQ: x0 => x0.name,
      AR: (x0,x1) => globalThis.firebase_messaging.onRegistered(x0,x1),
      AS: x0 => x0.phoneNumber,
      AT: (x0,x1) => globalThis.firebase_auth.signInWithPopup(x0,x1),
      AU: x0 => ({cacheSizeBytes: x0}),
      AV: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      B: s => printToConsole(s),
      BB: b => !!b,
      BC: Function.prototype.call.bind(DataView.prototype.setUint16),
      BD: x0 => x0.width,
      BE: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      BF: x0 => x0.wheelDeltaX,
      BG: x0 => x0.current(),
      BH: (x0,x1) => { x0.value = x1 },
      BI: x0 => x0.disabled,
      BJ: (x0,x1) => { x0.crossOrigin = x1 },
      BK: x0 => x0.convertToBlob(),
      BL: x0 => x0.action,
      BM: (x0,x1) => x0.key(x1),
      BN: x0 => x0.getSettings(),
      BO: x0 => x0.facingMode,
      BP: x0 => x0.x,
      BQ: (x0,x1) => { x0.lang = x1 },
      BR: x0 => x0.link,
      BS: x0 => x0.email,
      BT: (x0,x1) => x0.setCustomParameters(x1),
      BU: x0 => globalThis.firebase_firestore.persistentLocalCache(x0),
      BV: (x0,x1,x2,x3) => globalThis.firebase_firestore.onSnapshot(x0,x1,x2,x3),
      C: Function.prototype.call.bind(Number.prototype.toString),
      CB: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      CC: Function.prototype.call.bind(DataView.prototype.setUint8),
      CD: x0 => x0.screen,
      CE: x0 => new ResizeObserver(x0),
      CF: x0 => x0.key,
      CG: (x0,x1) => new Intl.v8BreakIterator(x0,x1),
      CH: (x0,x1,x2) => x0.setSelectionRange(x1,x2),
      CI: (x0,x1) => { x0.min = x1 },
      CJ: (x0,x1) => x0.createObjectURL(x1),
      CK: (x0,x1,x2) => new ImageData(x0,x1,x2),
      CL: x0 => x0.data,
      CM: x0 => x0.length,
      CN: x0 => x0.facingMode,
      CO: x0 => x0.height,
      CP: x0 => x0.cornerPoints,
      CQ: x0 => x0.pause(),
      CR: x0 => x0.analyticsLabel,
      CS: (x0,x1) => globalThis.firebase_auth.getMultiFactorResolver(x0,x1),
      CT: (x0,x1) => x0.addScope(x1),
      CU: (x0,x1,x2,x3) => ({ignoreUndefinedProperties: x0,experimentalForceLongPolling: x1,experimentalAutoDetectLongPolling: x2,localCache: x3}),
      CV: (x0,x1) => globalThis.firebase_firestore.collectionGroup(x0,x1),
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
      DG: x0 => x0.v8BreakIterator,
      DH: (x0,x1) => { x0.value = x1 },
      DI: (x0,x1) => { x0.max = x1 },
      DJ: x0 => x0.URL,
      DK: (x0,x1) => x0.getContext(x1),
      DL: x0 => x0.cancel(),
      DM: (x0,x1) => x0.removeItem(x1),
      DN: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      DO: x0 => x0.width,
      DP: x0 => x0.nextSibling,
      DQ: x0 => x0.cancel(),
      DR: x0 => x0.image,
      DS: x0 => x0.customData,
      DT: () => new firebase_auth.GoogleAuthProvider(),
      DU: () => globalThis.firebase_firestore.count(),
      DV: (x0,x1,x2) => globalThis.firebase_firestore.initializeFirestore(x0,x1,x2),
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
      EG: () => globalThis.Intl,
      EH: s => {
        if (/[[\]{}()*+?.\\^$|]/.test(s)) {
            s = s.replace(/[[\]{}()*+?.\\^$|]/g, '\\$&');
        }
        return s;
      },
      EI: (x0,x1) => { x0.disabled = x1 },
      EJ: x0 => new Blob(x0),
      EK: (x0,x1) => new OffscreenCanvas(x0,x1),
      EL: x0 => x0.resume(),
      EM: (x0,x1,x2) => x0.setItem(x1,x2),
      EN: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      EO: x0 => x0.attachStreamToVideo,
      EP: (x0,x1) => x0.debug(x1),
      EQ: x0 => x0.resume(),
      ER: x0 => x0.body,
      ES: x0 => x0.message,
      ET: (x0,x1) => globalThis.firebase_auth.signInWithRedirect(x0,x1),
      EU: x0 => globalThis.firebase_firestore.sum(x0),
      EV: (x0,x1) => globalThis.firebase_firestore.getFirestore(x0,x1),
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
      FG: (x0,x1) => x0.segment(x1),
      FH: x0 => x0.value,
      FI: (x0,x1) => { x0.scrollLeft = x1 },
      FJ: x0 => x0.close(),
      FK: x0 => x0.allocationSize(),
      FL: x0 => new SpeechSynthesisUtterance(x0),
      FM: (x0,x1) => x0.canShare(x1),
      FN: (x0,x1) => { x0.onpause = x1 },
      FO: () => new Map(),
      FP: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      FQ: (x0,x1) => x0.speak(x1),
      FR: x0 => x0.title,
      FS: x0 => x0.code,
      FT: x0 => x0.currentUser,
      FU: x0 => globalThis.firebase_firestore.average(x0),
      FV: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      G: s => JSON.stringify(s),
      GB: () => [],
      GC: (o, start, length) => new Float64Array(o.buffer, o.byteOffset + start, length),
      GD: x0 => x0.activeElement,
      GE: x0 => x0.documentElement,
      GF: x0 => x0.tiltY,
      GG: x0 => x0.index,
      GH: x0 => x0.selectionDirection,
      GI: (x0,x1) => { x0.spellcheck = x1 },
      GJ: (x0,x1) => ({frameIndex: x0,completeFramesOnly: x1}),
      GK: (x0,x1) => x0.copyTo(x1),
      GL: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      GM: (x0,x1) => x0.share(x1),
      GN: (x0,x1) => { x0.onplay = x1 },
      GO: (x0,x1,x2) => x0.set(x1,x2),
      GP: (x0,x1,x2,x3) => x0.toBlob(x1,x2,x3),
      GQ: (x0,x1) => { x0.text = x1 },
      GR: x0 => x0.fcmOptions,
      GS: x0 => x0.idToken,
      GT: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      GU: (x0,x1) => globalThis.firebase_firestore.getAggregateFromServer(x0,x1),
      GV: x0 => ({maxAttempts: x0}),
      H: Function.prototype.call.bind(Number.prototype.toString),
      HB: (a, i) => a.push(i),
      HC: (o, start, length) => new Float32Array(o.buffer, o.byteOffset + start, length),
      HD: x0 => x0.parentNode,
      HE: x0 => x0.computedStyleMap(),
      HF: x0 => x0.tiltX,
      HG: x0 => x0.next(),
      HH: x0 => x0.selectionStart,
      HI: (x0,x1) => { x0.disabled = x1 },
      HJ: (x0,x1) => x0.decode(x1),
      HK: (x0,x1) => { x0.height = x1 },
      HL: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      HM: x0 => x0.message,
      HN: (x0,x1) => { x0.controls = x1 },
      HO: (x0,x1) => x0.querySelector(x1),
      HP: x0 => x0.size,
      HQ: () => new SpeechSynthesisUtterance(),
      HR: x0 => x0.notification,
      HS: x0 => x0.secret,
      HT: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      HU: x0 => x0.data(),
      HV: (x0,x1,x2) => globalThis.firebase_firestore.runTransaction(x0,x1,x2),
      I: Function.prototype.call.bind(String.prototype.indexOf),
      IB: x0 => new Int8Array(x0),
      IC: (o, start, length) => new Uint32Array(o.buffer, o.byteOffset + start, length),
      ID: x0 => x0.tagName,
      IE: (x0,x1) => x0.get(x1),
      IF: x0 => x0.pointerType,
      IG: x0 => x0.value,
      IH: x0 => x0.selectionEnd,
      II: (x0,x1) => x0.getRandomValues(x1),
      IJ: x0 => x0.displayHeight,
      IK: (x0,x1) => { x0.width = x1 },
      IL: (x0,x1) => x0.speak(x1),
      IM: (x0,x1,x2) => ({files: x0,title: x1,text: x2}),
      IN: (x0,x1) => { x0.pointerEvents = x1 },
      IO: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      IP: (x0,x1,x2,x3,x4,x5) => x0.drawImage(x1,x2,x3,x4,x5),
      IQ: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      IR: x0 => x0.messageId,
      IS: x0 => x0.accessToken,
      IT: x0 => x0.hostname,
      IU: () => globalThis.firebase_firestore.Bytes,
      IV: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
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
      JG: x0 => x0.done,
      JH: x0 => x0.value,
      JI: () => globalThis.crypto,
      JJ: x0 => x0.displayWidth,
      JK: (x0,x1) => x0.toDataURL(x1),
      JL: (x0,x1) => { x0.onerror = x1 },
      JM: (x0,x1) => ({files: x0,text: x1}),
      JN: (x0,x1) => { x0.transformOrigin = x1 },
      JO: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      JP: x0 => x0.height,
      JQ: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      JR: x0 => x0.from,
      JS: x0 => x0.signInMethod,
      JT: x0 => x0.token,
      JU: x0 => x0.nanoseconds,
      JV: (o,s,v) => o[s] = v,
      K: o => o,
      KB: x0 => new Uint8Array(x0),
      KC: (o, start, length) => new Uint16Array(o.buffer, o.byteOffset + start, length),
      KD: x0 => x0.clientY,
      KE: (x0,x1) => { x0.textContent = x1 },
      KF: x0 => x0.getCoalescedEvents(),
      KG: (o, m, a) => o[m].apply(o, a),
      KH: x0 => x0.selectionDirection,
      KI: l => new DataView(new ArrayBuffer(l)),
      KJ: x0 => x0.duration,
      KK: (x0,x1,x2,x3) => x0.drawImage(x1,x2,x3),
      KL: (x0,x1) => { x0.onend = x1 },
      KM: (x0,x1) => ({files: x0,title: x1}),
      KN: (x0,x1) => { x0.objectFit = x1 },
      KO: x0 => x0.head,
      KP: x0 => x0.width,
      KQ: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      KR: x0 => x0.collapseKey,
      KS: x0 => x0.providerId,
      KT: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      KU: x0 => x0.seconds,
      KV: () => Symbol("jsBoxedDartObjectProperty"),
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
      LG: x0 => x0.iterator,
      LH: x0 => x0.selectionStart,
      LI: (a, i) => a.splice(i, 1),
      LJ: x0 => x0.image,
      LK: (x0,x1) => x0.getContext(x1),
      LL: x0 => { globalThis._activeSoundboxUtterance = x0 },
      LM: x0 => ({files: x0}),
      LN: (x0,x1) => { x0.width = x1 },
      LO: (x0,x1) => { x0.onerror = x1 },
      LP: (x0,x1) => { x0.src = x1 },
      LQ: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      LR: x0 => x0.data,
      LS: (x0,x1) => x0.getIdToken(x1),
      LT: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      LU: () => globalThis.firebase_firestore.Timestamp,
      LV: (x0,x1) => x0.delete(x1),
      M: x0 => x0.index,
      MB: x0 => new Int16Array(x0),
      MC: (o, start, length) => new Uint8ClampedArray(o.buffer, o.byteOffset + start, length),
      MD: (x0,x1,x2) => x0.setAttribute(x1,x2),
      ME: x0 => x0.matches,
      MF: s => s.trimLeft(),
      MG: () => globalThis.Symbol,
      MH: x0 => x0.selectionEnd,
      MI: a => a.pop(),
      MJ: (x0,x1,x2,x3,x4) => ({type: x0,data: x1,premultiplyAlpha: x2,colorSpaceConversion: x3,preferAnimation: x4}),
      MK: x0 => x0.format,
      ML: (x0,x1) => { x0.volume = x1 },
      MM: (x0,x1) => ({title: x0,text: x1}),
      MN: (x0,x1) => { x0.height = x1 },
      MO: (x0,x1) => x0.removeChild(x1),
      MP: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      MQ: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      MR: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      MS: x0 => x0.providerId,
      MT: (x0,x1,x2) => globalThis.firebase_app_check.onTokenChanged(x0,x1,x2),
      MU: () => globalThis.firebase_firestore.VectorValue,
      MV: (x0,x1,x2,x3) => x0.set(x1,x2,x3),
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
      NG: (x0,x1) => new Intl.Segmenter(x0,x1),
      NH: x0 => x0.keyCode,
      NI: (map, o, v) => map.set(o, v),
      NJ: x0 => new window.ImageDecoder(x0),
      NK: o => o.byteLength,
      NL: (x0,x1) => { x0.pitch = x1 },
      NM: () => ({}),
      NN: x0 => x0.getSupportedConstraints(),
      NO: (x0,x1) => { x0.onload = x1 },
      NP: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      NQ: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      NR: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      NS: x0 => x0.uid,
      NT: x0 => new firebase_app_check.ReCaptchaV3Provider(x0),
      NU: () => globalThis.firebase_firestore.GeoPoint,
      NV: (x0,x1,x2) => x0.set(x1,x2),
      O: o => o === undefined,
      OB: x0 => new Uint16Array(x0),
      OC: (o, start, length) => new Int8Array(o.buffer, o.byteOffset + start, length),
      OD: (ms, c) =>
      setTimeout(() => dartInstance.exports.$invokeCallback(c),ms),
      OE: x0 => x0.matches,
      OF: x0 => x0.pop(),
      OG: x0 => x0.Segmenter,
      OH: (x0,x1) => x0.scrollIntoView(x1),
      OI: (map, o) => map.get(o),
      OJ: x0 => x0.name,
      OK: () => new FileReader(),
      OL: (x0,x1) => { x0.rate = x1 },
      OM: x0 => globalThis.pdfjsLib.getDocument(x0),
      ON: x0 => ({ideal: x0}),
      OO: (x0,x1) => { x0.src = x1 },
      OP: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      OQ: (x0,x1) => { x0.onboundary = x1 },
      OR: (x0,x1) => globalThis.firebase_messaging.onMessage(x0,x1),
      OS: x0 => x0.providerData,
      OT: x0 => new firebase_app_check.ReCaptchaEnterpriseProvider(x0),
      OU: () => globalThis.firebase_firestore.DocumentReference,
      OV: x0 => ({merge: x0}),
      P: (x0,x1) => x0.exec(x1),
      PB: x0 => new Int32Array(x0),
      PC: (x0,x1) => x0.querySelector(x1),
      PD: s => new Date(s * 1000).getTimezoneOffset() * 60,
      PE: o => typeof o === 'function' && o[jsWrappedDartFunctionSymbol] === true,
      PF: x0 => x0.flags,
      PG: x0 => x0.buffer,
      PH: x0 => x0.multiViewEnabled,
      PI: () => new WeakMap(),
      PJ: x0 => x0.repetitionCount,
      PK: (x0,x1) => x0.readAsArrayBuffer(x1),
      PL: (x0,x1) => { x0.lang = x1 },
      PM: (x0,x1) => x0.getContext(x1),
      PN: (x0,x1,x2) => ({width: x0,height: x1,deviceId: x2}),
      PO: (x0,x1) => { x0.crossOrigin = x1 },
      PP: (x0,x1) => { x0.oncancel = x1 },
      PQ: (x0,x1) => { x0.onerror = x1 },
      PR: x0 => globalThis.firebase_messaging.getMessaging(x0),
      PS: x0 => x0.tenantId,
      PT: x0 => ({provider: x0}),
      PU: (x0,x1,x2) => globalThis.firebase_firestore.where(x0,x1,x2),
      PV: (x0,x1) => x0.get(x1),
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
      QG: x0 => x0.wasmMemory,
      QH: (x0,x1) => x0.replaceWith(x1),
      QI: x0 => new WeakRef(x0),
      QJ: x0 => x0.frameCount,
      QK: x0 => x0.result,
      QL: x0 => x0.paused,
      QM: (x0,x1) => x0.getPage(x1),
      QN: x0 => ({video: x0}),
      QO: (x0,x1) => { x0.lang = x1 },
      QP: (x0,x1) => { x0.onchange = x1 },
      QQ: (x0,x1) => { x0.onresume = x1 },
      QR: (x0,x1) => globalThis.firebase_messaging.register(x0,x1),
      QS: x0 => x0.refreshToken,
      QT: (x0,x1) => globalThis.firebase_app_check.initializeAppCheck(x0,x1),
      QU: (x0,x1) => globalThis.firebase_firestore.query(x0,x1),
      QV: (x0,x1) => x0.delete(x1),
      R: o => o,
      RB: x0 => new Uint32Array(x0),
      RC: x0 => x0.length,
      RD: (handle) => clearTimeout(handle),
      RE: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      RF: (x0,x1) => x0.error(x1),
      RG: () => globalThis.window._flutter_skwasmInstance,
      RH: (x0,x1) => { x0.type = x1 },
      RI: x0 => x0.deref(),
      RJ: x0 => x0.selectedTrack,
      RK: (x0,x1,x2,x3) => x0.addEventListener(x1,x2,x3),
      RL: x0 => x0.speaking,
      RM: (x0,x1) => x0.getViewport(x1),
      RN: (x0,x1) => ({width: x0,height: x1}),
      RO: (x0,x1) => { x0.type = x1 },
      RP: x0 => x0.type,
      RQ: (x0,x1) => { x0.onpause = x1 },
      RR: x0 => x0.measurementId,
      RS: x0 => x0.photoURL,
      RT: (x0,x1) => globalThis.firebase_analytics.setAnalyticsCollectionEnabled(x0,x1),
      RU: () => globalThis.firebase_firestore.and,
      RV: (x0,x1,x2,x3) => x0.set(x1,x2,x3),
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
      SG: () => new TextDecoder(),
      SH: (x0,x1) => { x0.className = x1 },
      SI: () => globalThis.WeakRef,
      SJ: x0 => x0.completed,
      SK: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      SL: x0 => x0.speechSynthesis,
      SM: (x0,x1) => x0.render(x1),
      SN: (x0,x1,x2) => ({width: x0,height: x1,facingMode: x2}),
      SO: (x0,x1) => { x0.defer = x1 },
      SP: x0 => x0.lastModified,
      SQ: (x0,x1) => { x0.onend = x1 },
      SR: x0 => x0.appId,
      SS: x0 => x0.phoneNumber,
      ST: (x0,x1) => globalThis.firebase_analytics.initializeAnalytics(x0,x1),
      SU: () => globalThis.firebase_firestore.or,
      SV: (x0,x1,x2) => x0.set(x1,x2),
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
      TG: (d, digits) => d.toFixed(digits),
      TH: (x0,x1) => { x0.tabIndex = x1 },
      TI: (o, offsetInBytes, lengthInBytes) => {
        var dst = new ArrayBuffer(lengthInBytes);
        new Uint8Array(dst).set(new Uint8Array(o, offsetInBytes, lengthInBytes));
        return new DataView(dst);
      },
      TJ: x0 => x0.ready,
      TK: (x0,x1,x2,x3) => x0.removeEventListener(x1,x2,x3),
      TL: () => new AudioContext(),
      TM: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      TN: (x0,x1) => x0.getUserMedia(x1),
      TO: (x0,x1) => { x0.async = x1 },
      TP: x0 => x0.name,
      TQ: (x0,x1) => { x0.onstart = x1 },
      TR: x0 => x0.messagingSenderId,
      TS: x0 => x0.lastSignInTime,
      TT: (o, a) => o + a,
      TU: x0 => globalThis.firebase_firestore.limitToLast(x0),
      TV: x0 => x0.commit(),
      U: (string, times) => string.repeat(times),
      UB: x0 => new Float64Array(x0),
      UC: x0 => x0.remove(),
      UD: x0 => x0.top,
      UE: (o, i) => o[i],
      UF: x0 => x0.blur(),
      UG: x0 => x0.maxHeight,
      UH: (x0,x1) => { x0.name = x1 },
      UI: (a, s, e) => a.slice(s, e),
      UJ: x0 => x0.tracks,
      UK: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      UL: x0 => x0.resume(),
      UM: (x0,x1) => x0.toBlob(x1),
      UN: x0 => x0.deviceId,
      UO: (x0,x1) => { x0.id = x1 },
      UP: (x0,x1) => x0.item(x1),
      UQ: x0 => x0.localService,
      UR: x0 => x0.authDomain,
      US: x0 => x0.creationTime,
      UT: x0 => x0.children,
      UU: x0 => globalThis.firebase_firestore.limit(x0),
      UV: x0 => globalThis.firebase_firestore.writeBatch(x0),
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
      VG: x0 => x0.maxWidth,
      VH: (x0,x1) => { x0.placeholder = x1 },
      VI: x0 => x0.message,
      VJ: () => globalThis.window.ImageDecoder,
      VK: () => new XMLHttpRequest(),
      VL: x0 => x0.createOscillator(),
      VM: x0 => x0.cleanup(),
      VN: x0 => x0.getCapabilities(),
      VO: x0 => x0.videoHeight,
      VP: x0 => x0.length,
      VQ: x0 => x0.voice,
      VR: x0 => x0.projectId,
      VS: x0 => x0.metadata,
      VT: x0 => x0.firstChild,
      VU: () => globalThis.firebase_firestore.endBefore,
      VV: x0 => globalThis.firebase_firestore.deleteDoc(x0),
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
      WG: x0 => x0.minHeight,
      WH: (x0,x1) => { x0.autocomplete = x1 },
      WI: (o, p) => p in o,
      WJ: (x0,x1) => x0.get(x1),
      WK: (x0,x1,x2,x3) => x0.open(x1,x2,x3),
      WL: x0 => x0.createGain(),
      WM: x0 => x0.destroy(),
      WN: () => ({}),
      WO: x0 => x0.videoWidth,
      WP: x0 => x0.files,
      WQ: x0 => x0.code,
      WR: x0 => x0.name,
      WS: x0 => x0.isAnonymous,
      WT: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      WU: () => globalThis.firebase_firestore.endAt,
      WV: x0 => globalThis.firebase_firestore.getDoc(x0),
      X: x0 => x0.dotAll,
      XB: (x0,x1,x2) => new Uint8Array(x0,x1,x2),
      XC: (x0,x1,x2,x3) => x0.setProperty(x1,x2,x3),
      XD: x0 => x0.clientY,
      XE: x0 => x0.language,
      XF: x0 => x0.innerWidth,
      XG: x0 => x0.minWidth,
      XH: (x0,x1) => { x0.name = x1 },
      XI: x0 => x0.groups,
      XJ: x0 => x0.body,
      XK: x0 => x0.send(),
      XL: (x0,x1,x2) => x0.setValueAtTime(x1,x2),
      XM: x0 => x0.height,
      XN: (x0,x1) => x0.applyConstraints(x1),
      XO: x0 => x0.stream,
      XP: x0 => x0.target,
      XQ: (x0,x1) => globalThis.firebase_storage.ref(x0,x1),
      XR: (x0,x1,x2,x3,x4,x5,x6,x7) => ({apiKey: x0,authDomain: x1,databaseURL: x2,projectId: x3,storageBucket: x4,messagingSenderId: x5,measurementId: x6,appId: x7}),
      XS: x0 => x0.emailVerified,
      XT: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      XU: () => globalThis.firebase_firestore.startAfter,
      XV: x0 => globalThis.firebase_firestore.getDocFromServer(x0),
      Y: x0 => x0.unicode,
      YB: (x0,x1,x2) => new DataView(x0,x1,x2),
      YC: x0 => x0.style,
      YD: x0 => x0.clientX,
      YE: (x0,x1,x2,x3) => x0.register(x1,x2,x3),
      YF: x0 => x0.height,
      YG: x0 => x0.debugSkipFontRetryDelay,
      YH: (x0,x1) => { x0.placeholder = x1 },
      YI: () => new AbortController(),
      YJ: x0 => x0.headers,
      YK: x0 => x0.type,
      YL: (x0,x1,x2) => x0.linearRampToValueAtTime(x1,x2),
      YM: x0 => x0.width,
      YN: (x0,x1) => { x0.whiteBalanceMode = x1 },
      YO: x0 => x0.play(),
      YP: (x0,x1) => x0.replaceChildren(x1),
      YQ: x0 => x0.name,
      YR: (x0,x1) => globalThis.firebase_core.initializeApp(x0,x1),
      YS: x0 => x0.email,
      YT: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      YU: () => globalThis.firebase_firestore.startAt,
      YV: x0 => globalThis.firebase_firestore.getDocFromCache(x0),
      Z: x0 => x0.ignoreCase,
      ZB: (o, p) => o[p],
      ZC: x0 => x0.debugShowSemanticsNodes,
      ZD: x0 => x0.changedTouches,
      ZE: () => globalThis.window.FinalizationRegistry,
      ZF: x0 => x0.width,
      ZG: x0 => x0.status,
      ZH: (x0,x1) => { x0.action = x1 },
      ZI: (x0,x1,x2,x3,x4,x5) => ({method: x0,headers: x1,body: x2,credentials: x3,redirect: x4,signal: x5}),
      ZJ: x0 => globalThis.setWebScreenshotProtection(x0),
      ZK: x0 => x0.response,
      ZL: (x0,x1,x2) => x0.exponentialRampToValueAtTime(x1,x2),
      ZM: x0 => x0.promise,
      ZN: x0 => x0.whiteBalanceMode,
      ZO: x0 => x0.paused,
      ZP: (x0,x1) => { x0.accept = x1 },
      ZQ: (x0,x1) => globalThis.firebase_storage.getStorage(x0,x1),
      ZR: x0 => globalThis.firebase_core.initializeApp(x0),
      ZS: x0 => x0.displayName,
      ZT: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      ZU: (x0,x1) => globalThis.firebase_firestore.orderBy(x0,x1),
      ZV: () => globalThis.firebase_firestore.updateDoc,
      a: x0 => x0.multiline,
      aB: (o) => new DataView(o.buffer, o.byteOffset, o.byteLength),
      aC: (x0,x1) => x0.warn(x1),
      aD: x0 => x0.offsetY,
      aE: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      aF: x0 => x0.clientHeight,
      aG: (x0,x1,x2) => x0.set(x1,x2),
      aH: (x0,x1) => { x0.method = x1 },
      aI: (x0,x1) => globalThis.fetch(x0,x1),
      aJ: x0 => x0.close(),
      aK: (x0,x1) => { x0.responseType = x1 },
      aL: (x0,x1) => x0.connect(x1),
      aM: (x0,x1) => { x0.viewport = x1 },
      aN: (x0,x1) => { x0.exposureMode = x1 },
      aO: (x0,x1,x2,x3) => x0.drawImage(x1,x2,x3),
      aP: (x0,x1) => { x0.multiple = x1 },
      aQ: x0 => globalThis.firebase_storage.getStorage(x0),
      aR: x0 => x0.storageBucket,
      aS: x0 => globalThis.firebase_auth.multiFactor(x0),
      aT: (x0,x1) => { x0.draggable = x1 },
      aU: x0 => x0.fromCache,
      aV: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
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
      bG: x0 => x0.arrayBuffer(),
      bH: (x0,x1) => { x0.noValidate = x1 },
      bI: (x0,x1) => x0.get(x1),
      bJ: x0 => x0.tag,
      bK: x0 => x0.vendor,
      bL: (x0,x1) => x0.start(x1),
      bM: (x0,x1) => { x0.canvasContext = x1 },
      bN: x0 => x0.exposureMode,
      bO: (x0,x1,x2,x3,x4) => x0.getImageData(x1,x2,x3,x4),
      bP: (x0,x1) => { x0.type = x1 },
      bQ: x0 => x0.name,
      bR: x0 => x0.databaseURL,
      bS: x0 => x0.call(),
      bT: x0 => new firebase_firestore.FieldPath(x0),
      bU: x0 => x0.hasPendingWrites,
      bV: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      c: (c) =>
      queueMicrotask(() => dartInstance.exports.$invokeCallback(c)),
      cB: o => o.byteOffset,
      cC: () => globalThis.window,
      cD: x0 => x0.type,
      cE: (x0,x1) => x0.unregister(x1),
      cF: (x0,x1) => { x0.content = x1 },
      cG: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof ArrayBuffer) return 1;
        if (globalThis.SharedArrayBuffer !== undefined &&
            o instanceof SharedArrayBuffer) {
          return 2;
        }
        return 3;
      },
      cH: (x0,x1) => x0.removeAttribute(x1),
      cI: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1,x2) { return wasmFunction(f,arguments.length,x0,x1,x2) }),
      cJ: x0 => x0.getNotifications(),
      cK: x0 => x0.navigator,
      cL: (x0,x1) => x0.stop(x1),
      cM: (x0,x1) => { x0.width = x1 },
      cN: (x0,x1) => { x0.focusMode = x1 },
      cO: (x0,x1,x2) => x0.readBarcodes(x1,x2),
      cP: (x0,x1) => x0.getAttribute(x1),
      cQ: x0 => globalThis.firebase_core.getApp(x0),
      cR: x0 => x0.apiKey,
      cS: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      cT: (x0,x1) => new firebase_firestore.FieldPath(x0,x1),
      cU: x0 => x0.metadata,
      cV: (x0,x1,x2) => globalThis.firebase_firestore.onSnapshot(x0,x1,x2),
      d: (x0,x1) => x0.didCreateEngineInitializer(x1),
      dB: o => o.buffer,
      dC: (o, c) => o instanceof c,
      dD: x0 => x0.maxTouchPoints,
      dE: (x0,x1) => x0.contains(x1),
      dF: (x0,x1) => { x0.name = x1 },
      dG: (x0,x1) => x0.fetch(x1),
      dH: x0 => x0.isConnected,
      dI: (x0,x1) => x0.forEach(x1),
      dJ: x0 => ({type: x0}),
      dK: () => globalThis.window,
      dL: x0 => x0.destination,
      dM: x0 => x0.width,
      dN: x0 => x0.focusMode,
      dO: x0 => x0.text,
      dP: (x0,x1) => x0.debug(x1),
      dQ: () => globalThis.firebase_core.getApp(),
      dR: x0 => x0.options,
      dS: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      dT: (x0,x1,x2) => new firebase_firestore.FieldPath(x0,x1,x2),
      dU: x0 => ({serverTimestamps: x0}),
      dV: x0 => x0.parent,
      e: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      eB: Function.prototype.call.bind(DataView.prototype.getUint8),
      eC: (x0,x1) => x0[x1],
      eD: x0 => x0.platform,
      eE: (s) => +s,
      eF: x0 => x0.head,
      eG: x0 => x0.fontFallbackBaseUrl,
      eH: x0 => x0.click(),
      eI: x0 => x0.name,
      eJ: (x0,x1) => new Blob(x0,x1),
      eK: x0 => new Blob(x0),
      eL: x0 => x0.gain,
      eM: (x0,x1) => { x0.height = x1 },
      eN: x0 => x0.enumerateDevices(),
      eO: x0 => x0.format,
      eP: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      eQ: x0 => x0.state,
      eR: () => globalThis.firebase_core.SDK_VERSION,
      eS: (x0,x1,x2) => x0.onIdTokenChanged(x1,x2),
      eT: (x0,x1,x2,x3) => new firebase_firestore.FieldPath(x0,x1,x2,x3),
      eU: x0 => x0.metadata,
      eV: x0 => x0.id,
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
      fG: (handle) => clearInterval(handle),
      fH: (x0,x1) => x0.getElementsByClassName(x1),
      fI: x0 => x0.statusText,
      fJ: x0 => globalThis.URL.createObjectURL(x0),
      fK: x0 => x0.abort(),
      fL: x0 => x0.frequency,
      fM: x0 => x0.height,
      fN: x0 => x0.deviceId,
      fO: x0 => x0.bytes,
      fP: x0 => ({createScriptURL: x0}),
      fQ: x0 => x0.snapshot,
      fR: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      fS: x0 => x0.toJSON(),
      fT: (x0,x1,x2,x3,x4) => new firebase_firestore.FieldPath(x0,x1,x2,x3,x4),
      fU: x0 => x0.toArray(),
      fV: x0 => globalThis.firebase_firestore.doc(x0),
      g: (x0,x1) => ({initializeEngine: x0,autoStart: x1}),
      gB: (b, o, l) => new DataView(b, o, l),
      gC: (string, token) => string.split(token),
      gD: () => globalThis.document,
      gE: s => s.trim(),
      gF: x0 => x0.firstChild,
      gG: (ms, c) =>
      setInterval(() => dartInstance.exports.$invokeCallback(c), ms),
      gH: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmF32ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      gI: x0 => x0.url,
      gJ: (x0,x1) => x0.createElement(x1),
      gK: x0 => x0.getRegistrations(),
      gL: (x0,x1) => { x0.type = x1 },
      gM: (x0,x1) => { x0.scale = x1 },
      gN: x0 => x0.kind,
      gO: x0 => x0.y,
      gP: (x0,x1,x2) => x0.createPolicy(x1,x2),
      gQ: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      gR: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      gS: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      gT: (x0,x1,x2,x3,x4,x5) => new firebase_firestore.FieldPath(x0,x1,x2,x3,x4,x5),
      gU: x0 => x0.toUint8Array(),
      gV: x0 => x0.path,
      h: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      hB: Function.prototype.call.bind(DataView.prototype.getFloat64),
      hC: o => o instanceof Array,
      hD: (x0,x1,x2) => x0.addEventListener(x1,x2),
      hE: x0 => x0.classList,
      hF: x0 => x0.viewConstraints,
      hG: () => Date.now(),
      hH: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmF64ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      hI: x0 => x0.status,
      hJ: (x0,x1,x2) => x0.setAttribute(x1,x2),
      hK: x0 => x0.keys(),
      hL: x0 => x0.currentTime,
      hM: x0 => x0.document,
      hN: x0 => x0.facingMode,
      hO: x0 => x0.x,
      hP: (x0,x1) => x0.createScriptURL(x1),
      hQ: (x0,x1) => x0.then(x1),
      hR: (x0,x1) => ({createScript: x0,createScriptURL: x1}),
      hS: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      hT: (x0,x1,x2,x3,x4,x5,x6) => new firebase_firestore.FieldPath(x0,x1,x2,x3,x4,x5,x6),
      hU: x0 => x0.longitude,
      hV: (x0,x1) => globalThis.firebase_firestore.collection(x0,x1),
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
      iG: (x0,x1,x2,x3) => x0.pushState(x1,x2,x3),
      iH: (x0,x1) => x0.dispatchEvent(x1),
      iI: x0 => x0.getReader(),
      iJ: (x0,x1) => x0.appendChild(x1),
      iK: (x0,x1) => x0.replace(x1),
      iL: x0 => x0.state,
      iM: x0 => x0.numPages,
      iN: x0 => x0.mediaDevices,
      iO: x0 => x0.bottomLeft,
      iP: (x0,x1) => { x0.nonce = x1 },
      iQ: (x0,x1,x2) => globalThis.firebase_storage.uploadBytesResumable(x0,x1,x2),
      iR: (x0,x1) => x0.createScriptURL(x1),
      iS: (x0,x1,x2) => x0.onAuthStateChanged(x1,x2),
      iT: (x0,x1,x2,x3,x4,x5,x6,x7) => new firebase_firestore.FieldPath(x0,x1,x2,x3,x4,x5,x6,x7),
      iU: x0 => x0.latitude,
      iV: x0 => x0.length,
      j: (x0,x1,x2) => x0.call(x1,x2),
      jB: Function.prototype.call.bind(DataView.prototype.setFloat64),
      jC: a => a.length,
      jD: x0 => x0.relatedTarget,
      jE: x0 => x0.parent,
      jF: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      jG: x0 => x0.history,
      jH: (x0,x1) => x0.createEvent(x1),
      jI: x0 => x0.read(),
      jJ: x0 => x0.click(),
      jK: x0 => x0.reload(),
      jL: x0 => globalThis.fetch(x0),
      jM: x0 => x0.promise,
      jN: () => globalThis.BarcodeDetector.getSupportedFormats(),
      jO: x0 => x0.bottomRight,
      jP: (x0,x1) => x0.querySelectorAll(x1),
      jQ: () => ({}),
      jR: (x0,x1,x2) => x0.createScript(x1,x2),
      jS: (x0,x1,x2) => ({errorMap: x0,persistence: x1,popupRedirectResolver: x2}),
      jT: (x0,x1,x2,x3,x4,x5,x6,x7,x8) => new firebase_firestore.FieldPath(x0,x1,x2,x3,x4,x5,x6,x7,x8),
      jU: (x0,x1) => x0.data(x1),
      jV: x0 => x0.assetBase,
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
      kG: (x0,x1,x2,x3) => x0.replaceState(x1,x2,x3),
      kH: (x0,x1,x2,x3) => x0.initEvent(x1,x2,x3),
      kI: x0 => x0.value,
      kJ: x0 => x0.remove(),
      kK: x0 => x0.href,
      kL: x0 => x0.arrayBuffer(),
      kM: (x0,x1) => { x0.cMapPacked = x1 },
      kN: (x0,x1) => x0.call(x1),
      kO: x0 => x0.topRight,
      kP: (x0,x1) => x0.item(x1),
      kQ: (x0,x1) => { x0.customMetadata = x1 },
      kR: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      kS: (x0,x1) => globalThis.firebase_auth.initializeAuth(x0,x1),
      kT: (x0,x1,x2,x3,x4,x5,x6,x7,x8,x9) => new firebase_firestore.FieldPath(x0,x1,x2,x3,x4,x5,x6,x7,x8,x9),
      kU: x0 => x0.path,
      kV: x0 => x0.loader,
      l: x0 => new Array(x0),
      lB: Function.prototype.call.bind(DataView.prototype.setFloat32),
      lC: x0 => x0.userAgent,
      lD: (decoder, codeUnits) => decoder.decode(codeUnits),
      lE: (x0,x1) => x0.hasAttribute(x1),
      lF: Function.prototype.call.bind(DataView.prototype.getBigInt64),
      lG: o => {
        const proto = Object.getPrototypeOf(o);
        return proto === Object.prototype || proto === null;
      },
      lH: x0 => x0.readText(),
      lI: x0 => x0.done,
      lJ: x0 => globalThis.URL.revokeObjectURL(x0),
      lK: x0 => x0.location,
      lL: x0 => x0.baseURI,
      lM: (x0,x1) => { x0.cMapUrl = x1 },
      lN: x0 => x0.reset,
      lO: x0 => x0.topLeft,
      lP: x0 => x0.nonce,
      lQ: (x0,x1) => { x0.contentType = x1 },
      lR: (o, p) => delete o[p],
      lS: () => globalThis.firebase_auth.browserPopupRedirectResolver,
      lT: () => globalThis.firebase_firestore.documentId(),
      lU: x0 => x0.ref,
      lV: () => globalThis._flutter,
      m: o => [o],
      mB: Function.prototype.call.bind(DataView.prototype.getFloat32),
      mC: x0 => x0.navigator,
      mD: () => new TextDecoder("utf-8", {fatal: true}),
      mE: x0 => x0.buttons,
      mF: Function.prototype.call.bind(DataView.prototype.setBigInt64),
      mG: o => Object.keys(o),
      mH: x0 => x0.clipboard,
      mI: x0 => x0.cancel(),
      mJ: x0 => x0.body,
      mK: (x0,x1) => x0.delete(x1),
      mL: x0 => x0.canvasKitMaximumSurfaces,
      mM: (x0,x1) => { x0.data = x1 },
      mN: x0 => x0.stopContinuousDecode,
      mO: x0 => x0.position,
      mP: x0 => x0.length,
      mQ: x0 => globalThis.firebase_storage.getDownloadURL(x0),
      mR: (o, p, v) => o[p] = v,
      mS: () => globalThis.firebase_auth.debugErrorMap,
      mT: (x0,x1) => new firebase_firestore.Timestamp(x0,x1),
      mU: x0 => x0.id,
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
      nG: x0 => x0.state,
      nH: (x0,x1) => x0.writeText(x1),
      nI: x0 => x0.body,
      nJ: (x0,x1) => { x0.display = x1 },
      nK: x0 => x0.caches,
      nL: x0 => x0.hostElement,
      nM: (x0,x1) => x0.append(x1),
      nN: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      nO: x0 => x0.isValid,
      nP: (x0,x1) => { x0.src = x1 },
      nQ: (x0,x1,x2) => globalThis.firebase_core.registerVersion(x0,x1,x2),
      nR: (x0,x1) => { x0.text = x1 },
      nS: () => globalThis.firebase_auth.browserSessionPersistence,
      nT: (x0,x1) => new firebase_firestore.GeoPoint(x0,x1),
      nU: x0 => x0.doc,
      o: (o0, o1, o2) => [o0, o1, o2],
      oB: Function.prototype.call.bind(DataView.prototype.getUint32),
      oC: Object.is,
      oD: (a, i, v) => a[i] = v,
      oE: x0 => x0.y,
      oF: () => typeof dartUseDateNowForTicks !== "undefined",
      oG: x0 => x0.state,
      oH: x0 => x0.unlock(),
      oI: x0 => x0.headers,
      oJ: x0 => x0.style,
      oK: x0 => x0.unregister(),
      oL: x0 => x0.location,
      oM: (x0,x1) => { x0.target = x1 },
      oN: (x0,x1,x2,x3) => x0.call(x1,x2,x3),
      oO: (x0,x1,x2,x3) => ({formats: x0,tryHarder: x1,tryRotate: x2,tryInvert: x3}),
      oP: x0 => x0.trustedTypes,
      oQ: x0 => x0.sessionStorage,
      oR: (x0,x1) => { x0.text = x1 },
      oS: () => globalThis.firebase_auth.browserLocalPersistence,
      oT: x0 => globalThis.firebase_firestore.vector(x0),
      oU: x0 => x0.newIndex,
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
      pF: () => Date.now(),
      pG: (x0,x1) => x0.go(x1),
      pH: (x0,x1) => x0.lock(x1),
      pI: x0 => x0.signal,
      pJ: (x0,x1) => { x0.href = x1 },
      pK: x0 => x0.serviceWorker,
      pL: (x0,x1) => x0.getModifierState(x1),
      pM: (x0,x1) => { x0.download = x1 },
      pN: x0 => x0.text,
      pO: (x0,x1,x2) => ({tryHarder: x0,tryRotate: x1,tryInvert: x2}),
      pP: () => globalThis.console,
      pQ: (x0,x1) => { x0.fetchTimeoutMillis = x1 },
      pR: x0 => x0.trustedTypes,
      pS: () => globalThis.firebase_auth.indexedDBLocalPersistence,
      pT: x0 => globalThis.firebase_firestore.Bytes.fromUint8Array(x0),
      pU: x0 => x0.oldIndex,
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
      qF: () => 1000 * performance.now(),
      qG: x0 => x0.hash,
      qH: x0 => x0.orientation,
      qI: () => {
        return typeof process != "undefined" &&
               Object.prototype.toString.call(process) == "[object process]" &&
               process.platform == "win32"
      },
      qJ: () => globalThis.document,
      qK: x0 => x0.getReader(),
      qL: x0 => x0.metaKey,
      qM: (x0,x1) => x0.getElementById(x1),
      qN: x0 => x0.barcodeFormat,
      qO: () => globalThis.ZXingWASM,
      qP: x0 => x0.trustedTypes,
      qQ: (x0,x1) => { x0.minimumFetchIntervalMillis = x1 },
      qR: (o, t) => typeof o === t,
      qS: x0 => x0.user,
      qT: (x0,x1) => globalThis.firebase_firestore.doc(x0,x1),
      qU: x0 => x0.type,
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
      rF: (x0,x1) => x0.requestAnimationFrame(x1),
      rG: x0 => x0.location,
      rH: (x0,x1) => x0.querySelector(x1),
      rI: () => {
        // On browsers return `globalThis.location.href`
        if (globalThis.location != null) {
          return globalThis.location.href;
        }
        return null;
      },
      rJ: (x0,x1,x2,x3) => x0.putImageData(x1,x2,x3),
      rK: x0 => x0.value,
      rL: x0 => x0.altKey,
      rM: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      rN: x0 => x0.rawBytes,
      rO: (x0,x1) => { x0.srcObject = x1 },
      rP: (wasmFunction,f) => finalizeWrapper(f, function() { return wasmFunction(f,arguments.length) }),
      rQ: x0 => x0.settings,
      rR: x0 => globalThis.firebase_auth.OAuthProvider.credentialFromError(x0),
      rS: x0 => globalThis.firebase_auth.OAuthProvider.credentialFromResult(x0),
      rT: (x0,x1,x2) => globalThis.firebase_firestore.setDoc(x0,x1,x2),
      rU: x0 => x0.docChanges(),
      s: () => globalThis,
      sB: o => o instanceof Uint16Array,
      sC: (x0,x1) => { x0.nonce = x1 },
      sD: x0 => x0.visibilityState,
      sE: x0 => x0.scrollLeft,
      sF: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      sG: x0 => x0.search,
      sH: (x0,x1) => { x0.title = x1 },
      sI: (x0,x1) => globalThis.updateWebBranding(x0,x1),
      sJ: x0 => x0.arrayBuffer(),
      sK: x0 => x0.done,
      sL: x0 => x0.ctrlKey,
      sM: (x0,x1,x2) => x0.addEventListener(x1,x2),
      sN: x0 => x0.y,
      sO: x0 => ({willReadFrequently: x0}),
      sP: x0 => { globalThis.onGoogleLibraryLoad = x0 },
      sQ: x0 => globalThis.firebase_remote_config.getRemoteConfig(x0),
      sR: x0 => x0.session,
      sS: x0 => x0.username,
      sT: (x0,x1) => globalThis.firebase_firestore.setDoc(x0,x1),
      sU: x0 => x0.docs,
      t: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      tB: Function.prototype.call.bind(DataView.prototype.getUint16),
      tC: x0 => x0.nonce,
      tD: (x0,x1,x2) => x0.removeEventListener(x1,x2),
      tE: x0 => x0.offsetLeft,
      tF: x0 => x0.now(),
      tG: x0 => x0.pathname,
      tH: (x0,x1) => x0.vibrate(x1),
      tI: x0 => globalThis.updateWebFavicon(x0),
      tJ: (x0,x1) => x0.transferFromImageBitmap(x1),
      tK: x0 => x0.read(),
      tL: x0 => x0.isComposing,
      tM: (x0,x1,x2) => x0.removeEventListener(x1,x2),
      tN: x0 => x0.x,
      tO: (x0,x1,x2) => x0.getContext(x1,x2),
      tP: x0 => x0.lang,
      tQ: (x0,x1) => { x0.defaultConfig = x1 },
      tR: x0 => x0.phoneNumber,
      tS: x0 => x0.providerId,
      tT: (wasmFunction,f) => finalizeWrapper(f, function() { return wasmFunction(f,arguments.length) }),
      tU: x0 => globalThis.firebase_firestore.getDocs(x0),
      u: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      uB: o => o instanceof Int16Array,
      uC: () => globalThis.window.flutterConfiguration,
      uD: x0 => x0.disconnect(),
      uE: x0 => x0.offsetParent,
      uF: x0 => x0.performance,
      uG: x0 => x0.parentElement,
      uH: x0 => x0.content,
      uI: (x0,x1) => x0.revokeObjectURL(x1),
      uJ: x0 => x0.height,
      uK: x0 => x0.getRegistration(),
      uL: x0 => x0.code,
      uM: (x0,x1) => { x0.innerHTML = x1 },
      uN: x0 => x0.resultPoints,
      uO: () => new BarcodeDetector(),
      uP: x0 => x0.getVoices(),
      uQ: x0 => globalThis.firebase_remote_config.fetchAndActivate(x0),
      uR: x0 => x0.uid,
      uS: x0 => x0.profile,
      uT: x0 => globalThis.firebase_firestore.increment(x0),
      uU: x0 => globalThis.firebase_firestore.getDocsFromServer(x0),
      v: (x0,x1) => ({addView: x0,removeView: x1}),
      vB: Function.prototype.call.bind(DataView.prototype.getInt16),
      vC: (x0,x1) => x0.attachShadow(x1),
      vD: x0 => new Intl.Locale(x0),
      vE: (o, p, r) => o.replace(p, () => r),
      vF: x0 => new Uint8Array(x0),
      vG: (x0,x1) => x0.querySelectorAll(x1),
      vH: x0 => x0.document,
      vI: (x0,x1) => { x0.src = x1 },
      vJ: x0 => x0.width,
      vK: (x0,x1) => x0.register(x1),
      vL: x0 => x0.repeat,
      vM: x0 => x0.permissions,
      vN: x0 => x0.message,
      vO: x0 => ({formats: x0}),
      vP: () => globalThis.speechSynthesis,
      vQ: (x0,x1) => globalThis.firebase_remote_config.getBoolean(x0,x1),
      vR: x0 => x0.enrollmentTime,
      vS: x0 => x0.isNewUser,
      vT: () => globalThis.firebase_firestore.arrayUnion,
      vU: x0 => globalThis.firebase_firestore.getDocsFromCache(x0),
      w: (l, r) => l === r,
      wB: o => o instanceof Uint8ClampedArray,
      wC: (x0,x1) => x0.createElement(x1),
      wD: x0 => x0.region,
      wE: (o, p, r) => o.replaceAll(p, () => r),
      wF: (x0,x1,x2) => x0.slice(x1,x2),
      wG: (x0,x1) => x0.removeProperty(x1),
      wH: (x0,x1,x2) => x0.insertBefore(x1,x2),
      wI: (x0,x1,x2,x3,x4) => globalThis.createImageBitmap(x0,x1,x2,x3,x4),
      wJ: x0 => x0.rasterEndMilliseconds,
      wK: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      wL: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      wM: x0 => x0.geolocation,
      wN: x0 => x0.videoElement,
      wO: x0 => new BarcodeDetector(x0),
      wP: (x0,x1) => { x0.pitch = x1 },
      wQ: (x0,x1) => globalThis.firebase_remote_config.getString(x0,x1),
      wR: x0 => x0.factorId,
      wS: x0 => globalThis.firebase_auth.getAdditionalUserInfo(x0),
      wT: () => globalThis.firebase_firestore.serverTimestamp(),
      wU: x0 => x0.source,
      x: x0 => x0.random(),
      xB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Uint8Array) return 1;
        return 2;
      },
      xC: x0 => x0.scale,
      xD: x0 => x0.script,
      xE: x0 => x0.deltaMode,
      xF: (x0,x1) => x0.decode(x1),
      xG: (x0,x1) => x0.add(x1),
      xH: x0 => x0.id,
      xI: x0 => x0.naturalHeight,
      xJ: x0 => x0.rasterStartMilliseconds,
      xK: (x0,x1) => { x0.onmessage = x1 },
      xL: x0 => x0.userAgent,
      xM: x0 => x0.mediaDevices,
      xN: x0 => x0.decodeContinuously,
      xO: (x0,x1) => x0.detect(x1),
      xP: (x0,x1) => { x0.volume = x1 },
      xQ: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      xR: x0 => x0.displayName,
      xS: x0 => globalThis.firebase_auth.getRedirectResult(x0),
      xT: () => globalThis.firebase_firestore.deleteField(),
      xU: x0 => ({source: x0}),
      y: () => globalThis.Math,
      yB: Function.prototype.call.bind(DataView.prototype.setInt32),
      yC: x0 => x0.visualViewport,
      yD: x0 => x0.language,
      yE: x0 => x0.deltaY,
      yF: (x0,x1) => x0.adoptText(x1),
      yG: x0 => x0.data,
      yH: x0 => x0.offsetHeight,
      yI: x0 => x0.naturalWidth,
      yJ: x0 => x0.imageBitmaps,
      yK: x0 => x0.payload,
      yL: (x0,x1,x2,x3) => x0.open(x1,x2,x3),
      yM: x0 => x0.baseURI,
      yN: (x0,x1) => new ZXing.BrowserMultiFormatReader(x0,x1),
      yO: x0 => x0.rawValue,
      yP: (x0,x1) => { x0.rate = x1 },
      yQ: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      yR: x0 => x0.hints,
      yS: x0 => x0.tenantId,
      yT: x0 => x0.id,
      yU: (x0,x1) => ({includeMetadataChanges: x0,source: x1}),
      z: (x0,x1) => x0.prepend(x1),
      zB: Function.prototype.call.bind(DataView.prototype.setUint32),
      zC: x0 => x0.devicePixelRatio,
      zD: x0 => x0.languages,
      zE: x0 => x0.deltaX,
      zF: x0 => x0.first(),
      zG: (x0,x1) => { x0.scrollTop = x1 },
      zH: x0 => x0.offsetWidth,
      zI: x0 => x0.decode(),
      zJ: (x0,x1) => { x0.height = x1 },
      zK: x0 => x0.reply,
      zL: (x0,x1) => x0.getItem(x1),
      zM: (x0,x1) => { x0.transform = x1 },
      zN: (x0,x1) => ({width: x0,height: x1}),
      zO: x0 => x0.format,
      zP: (x0,x1) => { x0.voice = x1 },
      zQ: (x0,x1) => ({next: x0,error: x1}),
      zR: x0 => x0.tenantId,
      zS: x0 => x0.signOut(),
      zT: x0 => globalThis.firebase_firestore.memoryLocalCache(x0),
      zU: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),

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
