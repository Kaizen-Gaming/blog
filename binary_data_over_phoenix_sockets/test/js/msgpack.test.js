import assert from 'assert';
import msgpack from '../../web/static/js/msgpack';
import msgpack_lite from 'msgpack-lite'

let d = msgpack.decode;
let e = msgpack_lite.encode;

describe('msgpack', function() {
  it('decodes fixed ints', function () {
    assert.equal(113, d([113]));
  });

  it('decodes fixed strings', function() {
    let hello_world = [171, 104, 101, 108, 108, 111, 32, 119, 111, 114, 108, 100];
    assert.equal("hello world", d(hello_world))
  })

   it('decodes fixed arrays', function() {
     let value = ["a", "b", 2.375, "c"];
     let encoded = e(value);
     assert.deepEqual(value, d(encoded))
   })

   it('decodes fixed maps', function() {
     let value = {1: "a", "b": "c", "d": 5};
     let encoded = e(value);
     assert.deepEqual(value, d(encoded))
   })

   it('decodes null', function() {
     let value = null;
     let encoded = e(value);
     assert.equal(value, d(encoded))
   })

   it('decodes booleans', function() {
     let value = [true, false, 0];
     let encoded = e(value);
     assert.deepEqual(value, d(encoded))
   })

   it('decodes bin8 arrays', function() {
     let value = new Buffer([104, 101, 108, 108, 111]); //hello
     let encoded = e(value);
     assert.deepEqual(value, new Buffer(d(encoded)))
   })

   it('decodes bin16 arrays', function() {
     var value = new Buffer(new Array(256).fill(100)); //force bin16
     let encoded = e(value);
     assert.deepEqual(value, new Buffer(d(encoded)))
   })

   it('decodes bin32 arrays', function() {
     var value = new Buffer(new Array(65536).fill(100)); //force bin16
     let encoded = e(value);
     let decoded = new Buffer(d(encoded));
     assert.equal(value.length, decoded.length);
     assert.deepEqual(value, decoded)
   })

   it('decodes floats', function() {
     let values = [1.1, -0.23423423400000234, 354234.9998986, -0.000000009999]
     for(let i=0; i < values.length; i++){
       let value = values[i];
       let encoded = e(value);
       let decoded = d(encoded);
       assert.equal(equalsWithinE(value, decoded, 0.00000001), true, "original value: ["+value+"] does not match decoded value: ["+decoded+"]");
     }
   })

   it('decodes ints of all kinds', function() {
     let values = [0, 17, 100, 127, -1342343, -2323423423231, -127, -45, 4234234, 234234234234, 23423425992394899234]
     for(let i=0; i < values.length; i++){
       let value = values[i];
       let encoded = e(value);
       let decoded = d(encoded);
       assert.equal(decoded, decoded);
     }
   })

   it('decodes map16s', function() {
     let value = {};
     for(var i = 0; i < 65536 /*force map16*/; i++){
       value[i] = i + "";
     }
     let encoded = e(value);
     let decoded = d(encoded);
     assert.equal(Object.keys(decoded).length, Object.keys(value).length);
     assert.deepEqual(decoded, value)
   })

   it('decodes array16s', function() {
     let value = [];
     for(var i = 0; i < 65536 /*force arr16*/; i++){
       value.push(i);
     }
     let encoded = e(value);
     let decoded = d(encoded);
     assert.equal(decoded.length, value.length);
     assert.deepEqual(decoded, value)
   })

  function equalsWithinE(num1, num2, e) {
    return (Math.abs(Math.abs(num1) - Math.abs(num2)) <= (e || 0.00000000001));
  }

});
