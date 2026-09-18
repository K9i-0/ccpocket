const $ = id => document.getElementById(id);
let socket, context, stream, node, source, active = false, recording = false, chunks = [], samples = [], audioBlob, audioUrl, startedAt, firstText, timer, stopping = false;
let logs = [], history = [], preparing = false, generation = 0, sessionConfig = {};
const state = text => $('status').textContent = text;
function log(value) { logs.push({ at: new Date().toISOString(), ...value }); logs = logs.slice(-300); $('log').textContent = logs.map(x => JSON.stringify(x)).join('\n'); }
function controls() { for (const id of ['model','version','context']) $(id).disabled = !!socket; $('connect').disabled = !!socket; $('disconnect').disabled = !socket; $('record').disabled = !active || recording || stopping || preparing; $('file').disabled = !active || recording || stopping || preparing; $('stop').disabled = !recording; }
function send(value) { if (socket?.readyState !== 1) throw new Error('接続がありません'); if (socket.bufferedAmount > 1024 * 1024) throw new Error('送信が追いつきません。再接続してください'); socket.send(JSON.stringify(value)); }
function fail(error) { $('error').textContent = error.message || String(error); log({ error: $('error').textContent }); }
function connect() {
  $('error').textContent = ''; state('接続中…');
  sessionConfig = { model: $('model').value.trim(), version: $('version').value, context: $('context').value };
  socket = new WebSocket(`ws://${location.host}/ws`); controls();
  socket.onmessage = event => {
    const msg = JSON.parse(event.data); log(msg);
    if (msg.type === 'ready') {
      if (!msg.allowed) { fail(new Error(`ChatGPT ログインが必要です（現在: ${msg.auth}）。ターミナルで codex login を実行してください。`)); disconnect(); return; }
      send({ type: 'start', ...sessionConfig });
    }
    if (msg.type === 'started') { active = true; state('接続済み・録音できます'); controls(); }
    if (msg.type === 'error' || msg.method === 'thread/realtime/error') { fail(new Error(msg.message || JSON.stringify(msg.params))); disconnect(); }
    if (msg.method === 'thread/realtime/closed') { active = false; state('セッション終了'); disconnect(); }
    const p = msg.params;
    if (msg.method === 'thread/realtime/transcript/delta' && p.role === 'user') { markText(); $('partial').textContent += p.delta; }
    if (msg.method === 'thread/realtime/transcript/done' && p.role === 'user') {
      markText(); $('draft').value += ($('draft').value ? '\n' : '') + p.text; $('partial').textContent = '';
    }
  };
  socket.onerror = () => fail(new Error('ローカルサーバーに接続できません'));
  socket.onclose = () => { socket = undefined; active = false; void release(); state('未接続'); controls(); };
}
function disconnect() { generation++; active = false; void release(); socket?.close(); controls(); }
function markText() { if (!firstText && startedAt) { firstText = performance.now() - startedAt; $('metrics').textContent = `最初の文字まで ${(firstText / 1000).toFixed(2)} 秒`; } }
function pcm(floats) { const bytes = new Uint8Array(floats.length * 2); const view = new DataView(bytes.buffer); floats.forEach((v,i) => view.setInt16(i*2, Math.round(Math.max(-1, Math.min(1,v)) * (v < 0 ? 32768 : 32767)), true)); return bytes; }
function transmit(floats) { const bytes = pcm(floats); let s = ''; for (const b of bytes) s += String.fromCharCode(b); send({ type: 'audio', data: btoa(s) }); }
function receive(floats) {
  if (!recording) return;
  samples.push(floats.slice()); chunks.push(...floats);
  while (chunks.length >= 2400) transmit(new Float32Array(chunks.splice(0,2400)));
}
function begin() { recording = true; chunks = []; samples = []; startedAt = performance.now(); firstText = undefined; $('partial').textContent = ''; $('error').textContent = ''; controls(); state('録音中'); }
async function record() {
  if (preparing || recording || !active) return; preparing = true; controls(); const operation = generation;
  try {
    stream = await navigator.mediaDevices.getUserMedia({ audio: { channelCount: 1, echoCancellation: true, noiseSuppression: true } });
    if (!active || operation !== generation) { await release(); return; }
    context = new AudioContext({ sampleRate: 24000 });
    if (context.sampleRate !== 24000) throw new Error('24 kHz の録音に対応していません。音声ファイルで試してください。');
    await context.audioWorklet.addModule('/capture.js'); if (!active || operation !== generation) { await release(); return; } await context.resume();
    source = context.createMediaStreamSource(stream); node = new AudioWorkletNode(context, 'capture');
    node.port.onmessage = event => { try { receive(event.data); } catch (error) { fail(error); disconnect(); } };
    source.connect(node); node.connect(context.destination); begin();
    timer = setTimeout(() => void stop(), 60000);
  } catch (error) { fail(error); await release(); } finally { preparing = false; controls(); }
}
async function release() {
  recording = false; clearTimeout(timer); source?.disconnect(); node?.disconnect(); stream?.getTracks().forEach(t => t.stop()); stream = undefined;
  const oldContext = context; context = undefined; if (oldContext && oldContext.state !== 'closed') await oldContext.close(); controls();
}
function wav() {
  const length = samples.reduce((n,s) => n+s.length,0); const data = new Float32Array(length); let offset=0;
  for (const s of samples) { data.set(s,offset); offset += s.length; }
  const bytes=pcm(data), head=new ArrayBuffer(44), v=new DataView(head);
  const text=(at,s)=> [...s].forEach((c,i)=>v.setUint8(at+i,c.charCodeAt(0)));
  text(0,'RIFF');v.setUint32(4,36+bytes.length,true);text(8,'WAVE');text(12,'fmt ');v.setUint32(16,16,true);v.setUint16(20,1,true);v.setUint16(22,1,true);v.setUint32(24,24000,true);v.setUint32(28,48000,true);v.setUint16(32,2,true);v.setUint16(34,16,true);text(36,'data');v.setUint32(40,bytes.length,true);
  return new Blob([head,bytes],{type:'audio/wav'});
}
async function stop() {
  if (!recording || stopping) return; stopping = true;
  await release();
  try {
    if (chunks.length) transmit(new Float32Array(chunks)); chunks=[];
    audioBlob=wav(); if(audioUrl) URL.revokeObjectURL(audioUrl); audioUrl=URL.createObjectURL(audioBlob); $('player').src=audioUrl; $('player').hidden=false; $('saveAudio').disabled=false;
    state('確定待ち…');
    for(let i=0;i<20 && active;i++) { transmit(new Float32Array(2400)); await new Promise(r=>setTimeout(r,100)); }
    if (active) state('接続済み・下書きを確認してください');
  } catch(error) { fail(error); } finally { stopping=false; controls(); }
}
async function fileInput() {
  const file=$('file').files[0]; if(!file || preparing || recording || !active) return; preparing=true; controls(); const operation=generation;
  try {
    if(file.size>20*1024*1024) throw new Error('20 MB 以下の音声を選んでください');
    const decoder=new AudioContext(); let decoded; try { decoded=await decoder.decodeAudioData(await file.arrayBuffer()); } finally { await decoder.close(); }
    if(decoded.duration>60) throw new Error('60 秒以下の音声を選んでください');
    const offline=new OfflineAudioContext(1,Math.ceil(decoded.duration*24000),24000); const input=offline.createBufferSource(); input.buffer=decoded;input.connect(offline.destination);input.start();
    const audio=(await offline.startRendering()).getChannelData(0); if(!active || operation !== generation) return; begin(); state('録音ファイルを送信中…');
    for(let i=0;i<audio.length && recording;i+=2400){ receive(audio.slice(i,i+2400)); await new Promise(r=>setTimeout(r,100)); }
    if(recording) await stop();
  } catch(error) { fail(error); await release(); } finally { preparing=false; $('file').value=''; controls(); }
}
function download(blob,name) { const url=URL.createObjectURL(blob), a=document.createElement('a');a.href=url;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000); }
$('connect').onclick=connect;$('disconnect').onclick=disconnect;$('record').onclick=record;$('stop').onclick=stop;$('file').onchange=fileInput;
$('saveAudio').onclick=()=>download(audioBlob,'voice-lab.wav');
$('copy').onclick=()=>navigator.clipboard.writeText($('draft').value).catch(fail);
$('save').onclick=()=>{ const item={ at:new Date().toISOString(),model:sessionConfig.model || 'default',version:sessionConfig.version,context:sessionConfig.context,text:$('draft').value,firstTextMs:firstText };history.push(item);const el=document.createElement('article');el.textContent=`${item.model} / ${item.version || 'default'}\n${item.text}`;$('history').prepend(el);$('draft').value=''; };
$('export').onclick=()=>download(new Blob([JSON.stringify({history,logs,draft:$('draft').value},null,2)],{type:'application/json'}),'voice-lab-results.json');
window.addEventListener('pagehide',disconnect);
