// ===== k-means おえかきAI =====

ArrayList<PVector> points;

int K = 2; // グループ数
PVector[] centroids;

void setup() {
  size(800, 600);
  points = new ArrayList<PVector>();

  centroids = new PVector[K];
  initCentroids();
  textSize(16);
}

void draw() {
  background(255);

  // 説明
  fill(0);
  text("クリックして点を描こう！", 20, 20);
  text("AIが似ている点をグループ分けするよ", 20, 40);

  if (points.size() > 0) {
    updateCentroids();
  }

  // 点を描画
  for (PVector p : points) {
    int c = classify(p.x, p.y);

    if (c == 0) fill(0, 0, 255); // 青
    else fill(255, 0, 0);        // 赤

    noStroke();
    circle(p.x, p.y, 10);
  }

  // 中心（AIの考え）を描画
  for (int i = 0; i < K; i++) {
    fill(0);
    stroke(0);
    circle(centroids[i].x, centroids[i].y, 20);
  }
}

// ===== マウスで点を追加 =====
void mousePressed() {
  points.add(new PVector(mouseX, mouseY));
}

// ===== 初期中心 =====
void initCentroids() {
  for (int i = 0; i < K; i++) {
    centroids[i] = new PVector(random(width), random(height));
  }
}

// ===== どのグループか判定 =====
int classify(float x, float y) {
  float minDist = 999999;
  int label = 0;

  for (int i = 0; i < K; i++) {
    float d = dist(x, y, centroids[i].x, centroids[i].y);
    if (d < minDist) {
      minDist = d;
      label = i;
    }
  }
  return label;
}

// ===== 学習（中心更新） =====
void updateCentroids() {
  PVector[] sum = new PVector[K];
  int[] count = new int[K];

  for (int i = 0; i < K; i++) {
    sum[i] = new PVector(0, 0);
    count[i] = 0;
  }

  for (PVector p : points) {
    int c = classify(p.x, p.y);
    sum[c].add(p);
    count[c]++;
  }

  for (int i = 0; i < K; i++) {
    if (count[i] > 0) {
      centroids[i] = PVector.div(sum[i], count[i]);
    }
  }
}
