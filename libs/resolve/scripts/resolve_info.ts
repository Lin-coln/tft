const images = [
  "./assets/images/img_1.png",
  "./assets/images/img_2.png",
  "./assets/images/img_3.png",
  "./assets/images/img_4.png",
];

for (const img of images) {
  const text = await Bun.$`echo ${img} | tft resolve`.text();
  console.log(JSON.stringify(JSON.parse(text), null, 2));
}
