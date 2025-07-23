const fs = require('fs');

const data = JSON.parse(fs.readFileSync("/Users/keni/Library/Application Support/Arc/StorableSidebar.json").toString())
// console.log(data.sidebar)
// console.log(data.sidebar.containers)
// console.log(data.sidebar.containers)
// console.log(data.sidebar.containers[1].items)

for (const space of data.sidebar.containers[1].spaces) {
  console.log(space)
}
// for (const item of data.sidebar.containers[1].items) {
//   // console.log(item)
//   if (item.data) {
//     console.log(item.parentID)
//     // if (!item.parentID) {
//     //   console.log(JSON.stringify(item, null, 2))
//     // }
//     console.log(JSON.stringify(item, null, 2))
//   }
//
//   // if (item.id === "2C422798-62FF-4218-81D2-F37ACB73ADF6") {
//   //   console.log(item)
//   // }
// }

// '9C99E69B-869A-479D-950D-DBD02EE52124',
// '849DF231-0B63-4148-A042-5CB3833C8D86',
// '92CF2189-0190-4BA2-9B67-740AB79D95B2',
// 'E14798BF-2401-4B93-9C3D-187AF803EC7D',
// '5026C310-6CEE-49F9-AC08-A68C150D55A2',
// 'FA0F96E4-8222-4074-B1FB-F1B1317CEA1E'
