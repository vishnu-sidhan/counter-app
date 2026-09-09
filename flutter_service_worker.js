'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"flutter_bootstrap.js": "8773f6909a613c2fd86b987b96265ff7",
"version.json": "bf7da883f2770f6bd573786e9e4dfdf0",
"index.html": "856fd801fe651b5f94ccfdecf024d6cd",
"/": "856fd801fe651b5f94ccfdecf024d6cd",
"main.dart.js": "3031df4a642824c8b8ed4b9c888bc5b5",
"flutter.js": "24bc71911b75b5f8135c949e27a2984e",
"favicon.png": "c44634f8585047099211f1c14db694b1",
"icons/Icon-192.png": "7ca32110a65d1ac1c2f18a17b3101137",
"icons/Icon-maskable-192.png": "7ca32110a65d1ac1c2f18a17b3101137",
"icons/Icon-maskable-512.png": "cb88ec1d21ec80ac29c9abce14c6f67e",
"icons/Icon-512.png": "cb88ec1d21ec80ac29c9abce14c6f67e",
"manifest.json": "72f7269427dffbd7c3dc0440f1bd6f14",
".git/config": "17598fab66cc351a729846df96b968e3",
".git/objects/59/d6ceed24d42e44f0ba4988123bd2bf16e955dd": "5f8b39cc4202c4c0b2711e12553669bd",
".git/objects/92/eab450609b7dc5d076ddf6c8416de8209373e0": "9b3d4cb7f5916a87f36a18b466ea7ac4",
".git/objects/66/664e8df0d4ee98939102e6bd73c22faff443b3": "61cb418d8b05073eec15ab51e61ea810",
".git/objects/68/43fddc6aef172d5576ecce56160b1c73bc0f85": "2a91c358adf65703ab820ee54e7aff37",
".git/objects/6f/7661bc79baa113f478e9a717e0c4959a3f3d27": "985be3a6935e9d31febd5205a9e04c4e",
".git/objects/32/06e4d569e1d4e1bd68719468699d7cbc6f7a50": "8b77542781299cd5f76006511546feb0",
".git/objects/35/57bdcc21969e63d1af0a926a463fa37b295109": "0fd33e1424a8a363fcddfa94a1fe2699",
".git/objects/69/b2023ef3b84225f16fdd15ba36b2b5fc3cee43": "6ccef18e05a49674444167a08de6e407",
".git/objects/51/486d58e395bd5589d41099afbe096f7c53afa9": "a0e468531cd7a0aa8fc476323f8c7459",
".git/objects/51/03e757c71f2abfd2269054a790f775ec61ffa4": "d437b77e41df8fcc0c0e99f143adc093",
".git/objects/93/b363f37b4951e6c5b9e1932ed169c9928b1e90": "c8d74fb3083c0dc39be8cff78a1d4dd5",
".git/objects/33/fd81e8316aac288193dc2526175059001e638f": "69c754c6f3df336401783bd4210c206a",
".git/objects/9c/3bee7658f7abf5e736f9e8185a977b2fbbf526": "aa5049a817fb6bd646174be9e383062d",
".git/objects/02/4ec2a78ffaa9a8398a8f6c3f49b3a4efeadb16": "797cf2c13869b9ef3cc2d944f5b5fe38",
".git/objects/a4/9d012b2611bbb4f6ddc7b7ecc595d50e306611": "dcb20733fdc74913719cce355c2ffe9d",
".git/objects/b5/2939363f86dd25736a8444be4f80cb8b0667e6": "55a6f94f14938da8e8af7283006e98b9",
".git/objects/d9/5b1d3499b3b3d3989fa2a461151ba2abd92a07": "a072a09ac2efe43c8d49b7356317e52e",
".git/objects/ad/ced61befd6b9d30829511317b07b72e66918a1": "37e7fcca73f0b6930673b256fac467ae",
".git/objects/ad/4c0ba9842f4de544316a62269732d33f652961": "d2648c4f7ac6a01d24dedabffef3980b",
".git/objects/d7/7cfefdbe249b8bf90ce8244ed8fc1732fe8f73": "9c0876641083076714600718b0dab097",
".git/objects/d7/7708e287d93cb44a74526a856a57b121f4d7fc": "78ac014b11be0976ea7ff436357ad439",
".git/objects/a5/38c4f07101eebc0a663c2c8361315a0433989c": "fe3cdd3615fc9c28ad52cf4dc3de7743",
".git/objects/a5/7d63e56ad9b10ee0f4262d30bad63a4a4e3a94": "1ed6daf971e999e1bee86cb68908da62",
".git/objects/e2/bb55ce131b00e5b0782a9fc9a52807358fe9b3": "af8e9e4f0a309252e7ff7737b90e82ba",
".git/objects/f3/3e0726c3581f96c51f862cf61120af36599a32": "afcaefd94c5f13d3da610e0defa27e50",
".git/objects/eb/ef3b50c5a38e40fbb947bc5de83c07d078c24d": "8ec787bb509cc14bb3308354bfa44923",
".git/objects/c9/20d0c1349a3f65935140a2f6e459195533640b": "e3179f658dec416e6116d50914997c29",
".git/objects/fc/13736fd934a7b603e2e7aa49afccc66ea0f8ea": "1db37ea7f3fd6d7d9e4471fefed2af04",
".git/objects/fd/05cfbc927a4fedcbe4d6d4b62e2c1ed8918f26": "5675c69555d005a1a244cc8ba90a402c",
".git/objects/f5/72b90ef57ee79b82dd846c6871359a7cb10404": "e68f5265f0bb82d792ff536dcb99d803",
".git/objects/e4/319c3be32b4eabc2026012fc385bc0fde43ff1": "04b1bb436ac63cdebf150dccb9d86950",
".git/objects/c8/3af99da428c63c1f82efdcd11c8d5297bddb04": "144ef6d9a8ff9a753d6e3b9573d5242f",
".git/objects/c1/8ee55f7488207f0d8d9ed1eb3ed70bc09e0449": "7d65d5c093a248a8c8422fa7cf13138a",
".git/objects/c6/83189a7177cb0937b5ec9d9c0c4161fa24e5c5": "51ea369d9bf4b21064a4c45fe68a6d83",
".git/objects/4e/0ef694ac0fb09aef3655d7ea6356e8e20db990": "1a85ef5029db8a1bf7d977e3674e7385",
".git/objects/18/8b865869574ddea97d8c0d1f6ef2d5883cb90f": "a4cac998c494b6aff4baa5f378196946",
".git/objects/27/64a008a775d3b22839de7ee8856d934219ace6": "a09ca56d18676aae8548f096a73a696e",
".git/objects/7c/3463b788d022128d17b29072564326f1fd8819": "37fee507a59e935fc85169a822943ba2",
".git/objects/42/6070a0a729f78ae89010ed31c6b66261f801bd": "76ce1abe344ade362740448e6ee01c9c",
".git/objects/1f/b64c02d62a066b57627af6ac2677e6f9c71b2c": "e9b5c6825f99a0c3a102da0570930e71",
".git/objects/74/ff016114305d88a6209afb6dc36ba4817c5dd2": "1f67009036e02777fdaaa9802c50b2e1",
".git/objects/17/f8a216f0481d79068f5b5d51bbd7965cec8b10": "c7dbf0918a96c31736f7f1f48bdedce4",
".git/objects/7e/034033fc1b8bd8bca9579f9864532f25f6da55": "9ae3c4755fb9860a52156892ecdfce07",
".git/objects/10/3e7077727917cad1541e3669bef441626fc20b": "812ce0ca2c94acd9088139851c60cf45",
".git/objects/10/b3c079d67e0d5d7ea53ef177e0fbb959b03479": "3097ff69ac2c673d92e732537d862344",
".git/objects/4c/ca4fbb67d51598d359e832a6767b18aaa8b422": "65e70b9385069646f06c95a34e77126f",
".git/objects/26/ea9e3f481984aeb923f410e488bf12757a6f55": "dfedd208c5069dae7ce7863ac16291aa",
".git/objects/21/ed8b863fbebb1dbdba0483b251d22537d6cb2a": "ed105878b650ecab0edaa07f408ea38f",
".git/objects/81/e9500a2cdf232e215acf53b045315793e4bff9": "968f882addd928bfc15ebc2880f67851",
".git/objects/86/652bcc48033f7924645406633843ace98cd72e": "f221b9b388b8fa6e14ae49c764ff39d3",
".git/objects/2f/2f36f32460900d7c83c3d4d873c8b8f3a5463d": "c0e2d20f482d7b23f1b7f4f39f18ac19",
".git/objects/2f/481ba383b0f9f8baef5bd117d09919eeca055b": "34268e40b441db20005e3233ad9c83bf",
".git/objects/43/37ab4e74d7b920da63a668991252904fee0181": "c0993ddfa5199d585daf979872080c81",
".git/objects/88/837f302f716ebe275bc675ce0c970350c3fcd9": "0d0776f09a07cf6cdee98e522e51e33b",
".git/objects/88/fb028111f10378fbd6875c82cf6cbc1421296f": "04a2fe6a11a5d225b136168c2756baad",
".git/objects/9f/8ad63f89800908641fd5dd0adf8108a3b6a843": "9fd3fb2a304f13e1db8dd0b8e7517526",
".git/objects/6b/9b02f4be90db2d72492b24c1dd4f3cc39d241d": "ff6a9083148e239ffb79fbb167d17fd3",
".git/objects/6b/9862a1351012dc0f337c9ee5067ed3dbfbb439": "85896cd5fba127825eb58df13dfac82b",
".git/objects/07/f00e2f853d1e45ad7eece3046ecc19d253abbb": "545b23d4c2e4dd9a1870cddbbbd0def8",
".git/objects/00/7d6ec3f52e33d02d9b135ec7e8854966c0506c": "7332e945b48cd7f4fe656c9882683e36",
".git/objects/6e/88711262c7deadd95c8c17dff5506a15c0c03c": "3f6d910a2082c1f9c9402663b5983a12",
".git/objects/5d/d3a1172ede08d3cdb7adf33c4e56209dd09c68": "02c5e006c77d3abb67023bba9a6dda78",
".git/objects/3a/8cda5335b4b2a108123194b84df133bac91b23": "1636ee51263ed072c69e4e3b8d14f339",
".git/objects/98/fc2b96a3ea0a8a1c9ff859ca5c2eeec171a55b": "48cffd11396bdea29b8ba5012ffe8beb",
".git/objects/53/bc76abbe9d71cd808a9ad3cf48ebadb63565c8": "3cab3cd38415e9c4e6dd346766a12e04",
".git/objects/08/27c17254fd3959af211aaf91a82d3b9a804c2f": "360dc8df65dabbf4e7f858711c46cc09",
".git/objects/99/1c205e7441d3b1d18ebdfde100d3754410b61c": "305100ce2be9457e170c554fa9b22bbe",
".git/objects/d3/d82ef29d725d45e7b0a155331ca7f2e1616c4f": "1e5b6dccd1201d2489115a8f16c4bfa2",
".git/objects/d4/3532a2348cc9c26053ddb5802f0e5d4b8abc05": "3dad9b209346b1723bb2cc68e7e42a44",
".git/objects/a7/21f275f7cc5e0c5df53aaa643eff9a203c8fef": "eb2212d8e09a11e08fe803a854f74768",
".git/objects/a7/02020b76e08872a494e366785db3817a19dd81": "5c4a279ffc9c5197371b1d717b0a1a82",
".git/objects/b8/efd5ca107d14c590c6cb9406cb8b459af4338c": "93c2708c5776de8a0a882bcc9c04b88f",
".git/objects/b1/ec582a235f175b40ce34e0eacec80d17f68f9c": "4e59c9e23e727ebe5f3fcfe209067fa0",
".git/objects/b1/77bc5827cec169aedab3b7994400abfe477747": "f813b18f3c2909964e6262d415f5ba3d",
".git/objects/a9/3941e4950faf5e37edf7da1eb82a07193b1910": "2832dcf27dd1fd91f8c6aac2be10b8a0",
".git/objects/d5/80ce749ea55b12b92f5db7747290419c975070": "8b0329dbc6565154a5434e6a0f898fdb",
".git/objects/af/e488729a0bc9bfb4813659935de2fcec51e93e": "aa3f848110a7c2595facf943450163e1",
".git/objects/db/25edd20ccc5e2a0bea7eafa3d3b8c1e8165d20": "fff1097074884b3882a04c5153a24266",
".git/objects/b9/2b34215e1ce1e24777a7accdd4bf72756970fc": "7f1a1c731938c93032ef8b723099bf1f",
".git/objects/b9/3e39bd49dfaf9e225bb598cd9644f833badd9a": "666b0d595ebbcc37f0c7b61220c18864",
".git/objects/a1/6bc2c9659df96e02a93aae95bdfa585668171c": "ece92dc8c8e5d71dc6dfd5219eb3d2ac",
".git/objects/c3/9c4c60e5a581b597a54c36231fc9fabbe5513f": "cb0a544da7a21748be16fc1ca25fc296",
".git/objects/cc/4a173cadb5c8ea165f599a79dadb220a7308c0": "abdda04b0ea3da9dd0bca8d3f0baa130",
".git/objects/e6/4b68f17a7233e3e3d31b807cb9960f8795b3ca": "c981ae85eac225b0737b936c1c1de677",
".git/objects/e6/eb8f689cbc9febb5a913856382d297dae0d383": "466fce65fb82283da16cdd7c93059ff3",
".git/objects/f9/f6f6948af46f7905388ee8e489703e427a1181": "40ea46d0c9f91fb472e04e8a2ca6e75e",
".git/objects/f9/45e66c0bebde6a8b072b7e8da72e37f2cda610": "2e029f804d1b18de9c1c0af47b84ed03",
".git/objects/c5/dde4646c611e76c2d4b520734ae53d093e18af": "26d71cf65729cb15431d9d68e08521bc",
".git/objects/c2/5acb371f64068d1b372e913ef171f5f9de89b2": "41606aff62322c3d7d8e39146dca0edf",
".git/objects/f6/2043d64744e3cca7d451440d0949adf8cea788": "7b38533a3a127a9dc67e9e17744787a8",
".git/objects/f6/e6c75d6f1151eeb165a90f04b4d99effa41e83": "95ea83d65d44e4c524c6d51286406ac8",
".git/objects/e9/94225c71c957162e2dcc06abe8295e482f93a2": "2eed33506ed70a5848a0b06f5b754f2c",
".git/objects/e9/9de2326ec3cea063afd29483cc1b2c8aabfced": "3bf960b4557ad511974d1b0a5568ec10",
".git/objects/46/4ab5882a2234c39b1a4dbad5feba0954478155": "2e52a767dc04391de7b4d0beb32e7fc4",
".git/objects/2c/b2bbeb4bd4f82bc6ecc6fb88d3db8ac2c64ed2": "de5ab907343e0d76b130b88efb523e16",
".git/objects/2c/e286ae2b7cd6a8bd0c6852c48bd48b708ab977": "377eeada19f507c60fcb9d6b47f60b63",
".git/objects/41/5c059c8094b888b0159fdedfd4e3cb08a8028e": "86914685ccd40e82a7fe5b70459fb9f7",
".git/objects/1e/b0a40857b15455c800314da3dab878d3e8483b": "d78195bb59300f3e64db0e207b2761c5",
".git/objects/84/4901e047c437887c6c1bdf40606ee8d1a2fa8e": "714d44921a33dd02ee9355490571cb6c",
".git/objects/8c/99266130a89547b4344f47e08aacad473b14e0": "41375232ceba14f47b99f9d83708cb79",
".git/objects/85/2de950d955e77dd97ee970bab185e019d51617": "41d41674563400a730271caf6683d539",
".git/objects/85/63aed2175379d2e75ec05ec0373a302730b6ad": "997f96db42b2dde7c208b10d023a5a8e",
".git/objects/76/0ff6af40e4946e3b2734c0e69a6e186ab4d8f4": "009b8f1268bb6c384d233bd88764e6f8",
".git/objects/1c/5f50e6a817ff773f3071af374de1e58b6b61dc": "3b23cc09b0a53335fb4fd62bf6fcabe4",
".git/objects/1c/7ee3b9fe5b4b7ccbf9f5b796931a169f10e477": "70d5fe7ade93fd8a9f233beb970335f0",
".git/objects/47/78bd399f0df0b812f600c131429274d783bf6e": "0ac07076013b92ea938607ad320f41a4",
".git/objects/47/f3ef503b8322b0943aedf1ddc0783875751aff": "382584402250a6738683c548012fb960",
".git/objects/14/7e7f24930170b58d6888d10bb93ce221707a66": "927509c5383a20986da7dd9ee82f6bb5",
".git/HEAD": "5ab7a4355e4c959b0c5c008f202f51ec",
".git/info/exclude": "036208b4a1ab4a235d75c181e685e5a3",
".git/logs/HEAD": "6b307e66483803bcf808f9a347672f7f",
".git/logs/refs/heads/gh-pages": "2a64d77a90969b2d5a491be0a974b7c0",
".git/logs/refs/remotes/origin/gh-pages": "7da1f1b82d30dd1f251876720e937b8b",
".git/description": "a0a7c3fff21f2aea3cfa1d0316dd816c",
".git/hooks/commit-msg.sample": "579a3c1e12a1e74a98169175fb913012",
".git/hooks/pre-rebase.sample": "56e45f2bcbc8226d2b4200f7c46371bf",
".git/hooks/sendemail-validate.sample": "4d67df3a8d5c98cb8565c07e42be0b04",
".git/hooks/pre-commit.sample": "5029bfab85b1c39281aa9697379ea444",
".git/hooks/applypatch-msg.sample": "ce562e08d8098926a3862fc6e7905199",
".git/hooks/fsmonitor-watchman.sample": "a0b2633a2c8e97501610bd3f73da66fc",
".git/hooks/pre-receive.sample": "2ad18ec82c20af7b5926ed9cea6aeedd",
".git/hooks/prepare-commit-msg.sample": "2b5c047bdb474555e1787db32b2d2fc5",
".git/hooks/post-update.sample": "2b7ea5cee3c49ff53d41e00785eb974c",
".git/hooks/pre-merge-commit.sample": "39cb268e2a85d436b9eb6f47614c3cbc",
".git/hooks/pre-applypatch.sample": "054f9ffb8bfe04a599751cc757226dda",
".git/hooks/pre-push.sample": "2c642152299a94e05ea26eae11993b13",
".git/hooks/update.sample": "647ae13c682f7827c22f5fc08a03674e",
".git/hooks/push-to-checkout.sample": "c7ab00c7784efeadad3ae9b228d4b4db",
".git/refs/heads/gh-pages": "8f5563f150de103c4c7ba7c93a437793",
".git/refs/remotes/origin/gh-pages": "b4a076dc234d5e6fcdce2ef20d34de2d",
".git/index": "ef027addb3d877597bc86b265542d92c",
".git/COMMIT_EDITMSG": "53431c86837517c387ff559994141e98",
"assets/NOTICES": "66fa60f6d1d0ab4f9e9c7b08c7aac565",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/AssetManifest.bin.json": "9a913970039d9766d3ba9fb5cdc3c353",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/shaders/stretch_effect.frag": "40d68efbbf360632f614c731219e95f0",
"assets/AssetManifest.bin": "07d5cd6ab3f30296e47167f93c8c3ac3",
"assets/fonts/MaterialIcons-Regular.otf": "cb6ffec5a31c4477211bf4deada9e947",
"assets/assets/icon/app_icon.png": "c0e8feb7e3dd79f80c92b08072a800b3",
"canvaskit/skwasm.js": "8060d46e9a4901ca9991edd3a26be4f0",
"canvaskit/skwasm_heavy.js": "740d43a6b8240ef9e23eed8c48840da4",
"canvaskit/skwasm.js.symbols": "3a4aadf4e8141f284bd524976b1d6bdc",
"canvaskit/canvaskit.js.symbols": "a3c9f77715b642d0437d9c275caba91e",
"canvaskit/skwasm_heavy.js.symbols": "0755b4fb399918388d71b59ad390b055",
"canvaskit/skwasm.wasm": "7e5f3afdd3b0747a1fd4517cea239898",
"canvaskit/chromium/canvaskit.js.symbols": "e2d09f0e434bc118bf67dae526737d07",
"canvaskit/chromium/canvaskit.js": "a80c765aaa8af8645c9fb1aae53f9abf",
"canvaskit/chromium/canvaskit.wasm": "a726e3f75a84fcdf495a15817c63a35d",
"canvaskit/canvaskit.js": "8331fe38e66b3a898c4f37648aaf7ee2",
"canvaskit/canvaskit.wasm": "9b6a7830bf26959b200594729d73538e",
"canvaskit/skwasm_heavy.wasm": "b0be7910760d205ea4e011458df6ee01"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
