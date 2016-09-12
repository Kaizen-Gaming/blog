import msgpack from "./msgpack"

/*lots of console.log() statements for educational purposes in this file, don't forget to remove them in production*/

function convertToBinary(socket){

  let parentOnConnOpen = socket.onConnOpen;

  socket.onConnOpen = function(){
    //setting this to arraybuffer will help us not having to deal with blobs
    this.conn.binaryType = 'arraybuffer';
    parentOnConnOpen.apply(this, arguments);
  }

  //we also need to override the onConnMessage function, where we'll be checking
  //for binary data, and delegate to the default implementation if it's not what we expected
  let parentOnConnMessage = socket.onConnMessage;

  socket.onConnMessage = function (rawMessage){
    if(!(rawMessage.data instanceof window.ArrayBuffer)){
      return parentOnConnMessage.apply(this, arguments);
    }
    let msg = decodeMessage(rawMessage.data);
    let topic = msg.topic;
    let event = msg.event;
    let payload = msg.payload;
    let ref = msg.ref;

    this.log("receive", (payload.status || "") + " " + topic + " " + event + " " + (ref && "(" + ref + ")" || ""), payload);
    this.channels.filter(function (channel) {
      return channel.isMember(topic);
    }).forEach(function (channel) {
      return channel.trigger(event, payload, ref);
    });
    this.stateChangeCallbacks.message.forEach(function (callback) {
      return callback(msg);
    });
  }

  return socket;
}

function decodeMessage(rawdata){
  if(!rawdata){
    return;
  }

  let binary = new Uint8Array(rawdata);
  let data;
  //check for gzip magic bytes
  if(binary.length > 2 && binary[0] === 0x1F && binary[1] === 0x8B){
    let inflate = new window.Zlib.Gunzip(binary);
    data = inflate.decompress();
    console.log('received', binary.length, 'Bytes of gzipped data,', data.length, 'Bytes after inflating');
  }
  else{
    console.log('received', binary.length, 'Bytes of plain msgpacked data');
    data = binary;
  }
  let msg = msgpack.decode(data);
  return msg;
}

export default {
  convertToBinary
}
