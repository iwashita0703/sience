// Server Client communication //<>// //<>//
// 先に立ち上げたらサーバ，後に立ち上げたらクライアントになるようにしたい
import controlP5.*;
ControlP5 cp;
PFont japaneseFont, ansFont;

int posX=1, posY=3;  // 描画データの位置 (0: 顔幅， 1:顔高さ， 2:耳幅， 3:耳高さ

String ip = "127.0.0.1"; // 特定のIPアドレスを設定します
int port=52130; // 待ち受けポート
String displayTitle="熊本高専「おもしろサイエンス・わくわく実験講座2025」";

int Rwidth=720;
int Rheight=640;
float minX, minY, maxX, maxY;

float [] widthList, heightList;
PVector [] minList;

PFont normalFont, titleFont;

int grid=10;  // 図形グリッド描画とリサイズ係数に使用

// Coordinate space
float xmin, ymin, xmax, ymax;
int maxFigs=30; // 図形の最大数

String nickname, judgeLabel; // CSVのヘッダ情報を格納
String [] label; // CSV ラベル

boolean debug=false;
boolean debug2=false; // for perceptron debug

// A list of points we will use to "train" the perceptron
// A Perceptron object
Perceptron ptron1;  // 表示用（顔高さ，耳高さ）
Perceptron ptron2;  // 判定用（顔高さ，耳高さ，耳幅）
MyMap map;  // マッピング＆グラフ描画


ArrayList <ArrayList <PVector>> figs;
ArrayList <PVector> fig;

//int n;// csvファイルに含まれるデータ数（ヘッダ含まず）

ControlP5 cp5;
Textfield inputField;
Textlabel myJudgeLabel1, myReaction;
Button myYesButton, myNoButton, myJudgeButton;
Toggle myEasyMode;
boolean EasyMode=false;
boolean finished;
boolean findIP=false;  // 指定したIPアドレスを自分自身で使用していたらTrueにする

void setup() {
  frameRate(60);
  size(1024, 768);
  background(255);
  normalFont=createFont("monospaced", 18);
  textFont(normalFont);
  titleFont=createFont("monospaced", 28);
  String myip;
  figs = new ArrayList <ArrayList<PVector>>();

  // すべてのインターフェースについて，指定したIPが使用されていないか調査
  try {
    // ネットワークインターフェースを列挙
    Enumeration<NetworkInterface> interfaces = NetworkInterface.getNetworkInterfaces();
    while (!findIP && interfaces.hasMoreElements()) {
      NetworkInterface iface = interfaces.nextElement();
      if (iface.isUp()) {
        String interfaceName = iface.getDisplayName(); // インターフェース名を取得

        Enumeration<InetAddress> addresses = iface.getInetAddresses();
        while (!findIP && addresses.hasMoreElements()) {
          InetAddress addr = addresses.nextElement();
          if (!addr.getHostAddress().contains(":")) {
            // IPv6アドレスは使用しない. IPv4アドレスのみ
            myip=addr.getHostAddress();
            println("Find interface:"+interfaceName + "  ip="+myip);
            if (myip.equals(ip)) findIP=true;
          }
        }
      }
    }
  }
  catch (SocketException e) {
    println("ネットワークインターフェースの取得に失敗しました。");
  }

  if (findIP) {
    try {
      server = new Server(this, port); // サーバIPなら、サーバとして起動します
      println("Running as a server");
    }
    catch(Exception e) {
      client = new Client(this, ip, port); // サーバ（自分自身）に接続を試みます
      println("Running as a client");
    }
  } else {
    client = new Client(this, ip, port); // サーバ（他者）に接続を試みます
    println("Running as a client");
  }

  label = new String[5];
  Table table = loadTable("training.csv"); // トレーニング用には4つのパラメータが含まれる
  int n=table.getColumnCount();
  nickname=table.getString(0, 0); // ニックネーム
  print("name="+nickname);
  for (int i=0; i<n-2; i++) { // 名前と判定結果を省いて読み込み
    label[i]=table.getString(0, i+1);  // 何から
    print(", label["+i+"]="+label[i]);
  }
  judgeLabel=table.getString(0, n-1);   // 何を判定するのか？
  // println(", what="+judgeLabel);

  ptron1 = new Perceptron(3, 0.001);  // 顔幅，耳高（グラフ描画）
  // println("ptron1.n="+ptron1.n);
  ptron2 = new Perceptron(5, 0.001);  // 顔幅，顔高，耳幅，耳高（うさぎ判定用）

  if (server!=null) {
    loadTrainingData(n-2);  // 学習データの再読み込み
    createServerGUI();
    createGraph();
  } else if (client != null) {
    widthList = new float[maxFigs];
    heightList = new float[maxFigs];
    minList = new PVector[maxFigs];
    createClientGUI();
    clearSketch();
  }
}

void PrintPicture() {
  saveFrame("screenshot-"+nf(year(), 2)+nf(month(), 2)+nf(day(), 2)+nf(hour(), 2)+nf(minute(), 2)+nf(second(), 2)+".png");
}


void selectX(int n) {
  //  println("X Event "+n);
  if (0<=n && n<4) {
    posX=n;
    ptron1.weights[posX]=random(-1, 1);
    for (int i=0; i<4; i++) {
      if (i != posX && i != posY) ptron1.weights[i]=0;
    }
  }
  server.write("AI:x "+posX);
}

void selectY(int n) {
  //  println("Y Event "+n);
  if (0<=n && n<4) posY=n;
  ptron1.weights[posY]=random(-1, 1);
  for (int i=0; i<4; i++) {
    if (i != posX && i != posY) ptron1.weights[i]=0;
  }
  server.write("AI:y "+posY);
}

void EasyMode() {
  EasyMode=!EasyMode;
  //clearSketch();  // トグルを変更するごとに初期化
}

void reloadTable() {
  println("reload table");
  loadTrainingData(4);
  ptron1 = new Perceptron(3, 0.001);  // 顔幅，耳高（グラフ描画）
}

void resetTable() {
  println("reset table");
  training = new ArrayList <Trainer>();  // 空のトレーニングリストを作成
  float [] w = new float[ptron1.weights.length];
  w[posX]=1.0;
  w[posY]=1.0;
  ptron1.weights = w;
}

void createGraph() {
  // ptron1 のグラフ描画のため，ｘ，ｙの最大・最小を取得
  xmin=ymin=0;
  for (Trainer t : training) {
    if (xmax<t.x[posX]) xmax=t.x[posX];  // 顔高さ（グラフ描画に用いるパラメータ）
    if (ymax<t.x[posY]) ymax=t.x[posY];  // 耳高さ
    println(t.name, t.x[0], t.x[1], t.x[2], t.x[3], t.answer);  // 読み込んだデータを表示
  }
  xmax=Rwidth/grid;
  ymax=Rheight/grid;
  //println(xmax, ymax);
  map=new MyMap(new PVector(0.0, 0.0), new PVector(xmax, ymax), new PVector(50.0, height-120.0), new PVector(width-20.0, 20.0));
}


void showGrid() {
  background(255);
  noStroke();
  fill(255);
  rect(0, 0, Rwidth, Rheight);
  //fill(0);
  //rect(Rwidth, 0, 240, Rheight);
  strokeWeight(1);
  // グリッド描画
  for (int x=0; x<Rwidth; x+=grid) {
    if ((x%(grid*10)) == grid) stroke(0);
    else  stroke(192);
    line(x, 0, x, Rheight);
  }
  for (int y=0; y<=Rheight; y+=grid) {
    if ((y%(grid*10)) == grid) stroke(0);
    else  stroke(192);
    line(0, y, Rwidth, y);
  }
  fill(0);
  textAlign(TOP, CENTER);
  text("←ここに"+char(10)+" ウサギかクマを書いてね！", Rwidth+(240-200)/2-10, 100);
}

void loadTrainingData(int n) {
  // CSVファイルを読み込む
  // ここでは全パラメータを用いたトレーニングデータを作成
  // グラフ描画に用いる2パラメータパーセプトロンは学習時に情報削減する
  training = new ArrayList <Trainer>();  // 空のトレーニングリストを作成
  String [] files = { "training.csv", "training-user.csv" };
  for (String file : files) {
    Table table = loadTable(file, "header");
    for (TableRow row : table.rows()) {
      float [] x= new float[n+1];
      String name=row.getString(nickname);
      for (int i=0; i<n; i++) {
        x[i]=row.getFloat(label[i]);
      }
      x[n]=1; // bias
      int answer=row.getInt(judgeLabel);  // 教師データ[-1, 1] を読み込む
      Trainer t=new Trainer(name, x, answer);// トレーニング用データの作成
      training.add(t);
    }
  }
}

void draw() {
  // 描画速度をチェック
  if (frameCount == 300 ) println("FrameRate="+frameRate);

  if (server != null) {
    // サーバ動作
    // クライアントへ学習状況weights[]を送信
    // 送信データフォーマット
    // AI:w w1 w2 w3 w4
    // クライアントから新たなトレーニングデータを受信
    // トレーニング状況を可視化

    float [] w1=ptron1.getWeights();
    float [] w2=ptron2.getWeights();
    sendWeightsBroadcast(server, w1, w2);  //重みをクライアントにブロードキャスト

    Client c = server.available();
    if (c != null) {
      if (debug) println("c not null");
      String input = c.readString(); // クライアントから学習データ受信
      // 受： AI:t name 10 8 10 2 (1|-1)
      println("Received: " + input);
      String [] s = split(input, ' ');
      if (s[0].equals("AI:t")) {
        float [] x = new float [w1.length];
        for (int i=0; i<x.length-1; i++) {
          x[i] = float(s[i+2]);
        }
        x[x.length-1]=1; // for bias
        String name=s[1];
        int answer=int(s[s.length-1]);
        Trainer t=new Trainer(name, x, answer);
        training.add(t);
        //createGraph();
      }
      // クライアントへ重みを送出
    }

    // Train the Perceptron with one "training" point at a time
    for (Trainer t : training) {
      if (t.isActive()) {
        ptron1.train(t);
        ptron2.train(t);
      }
      if (debug) {
        float []w=ptron1.getWeights();
        println("w=(", w[posX], w[posY], w[w.length-1]+")");
      }
    }
    ptron1.normalize(1.0);  // 正規化
    ptron2.normalize(1.0);  // 正規化
    map.myDrawMap(training);
  } else if (client != null) {
    // クライアント動作
    // サーバへ新たなトレーニングデータを送信する
    // 送受信フォーマット
    // 送： AI:t name 10 12 8 4 1 (x * n + answer)
    // 受： AI:p 0.5 -0.7 0.2

    // サーバから学習状況weights[]を受け取りperceptronに反映
    // 受： AI:w1 w[0] w[1] w[2] w[3] // ptron1
    // 受： AI:w2 w[0] w[1] w[2] w[3] // ptron2
    // weights をサーバから再読み込み
    if (client.available()>0) {
      String wstr=client.readString();
      float [] w1, w2;
      w1=ptron1.getWeights();
      w2=ptron2.getWeights();
      if (wstr!=null) {
        if (debug) println("Received: " + wstr);
        String [] s = split(wstr, ' ');
        if (s[0].equals("AI:w1")) {
          for (int i=0; i<s.length-1; i++) w1[i]=float(s[i+1]);
        } else if (s[0].equals("AI:w2")) {
          for (int i=0; i<s.length-1; i++) w2[i]=float(s[i+1]);
        } else if (s[0].equals("AI:x")) {
          posX=int(s[1]);
        } else if (s[0].equals("AI:y")) {
          posY=int(s[1]);
        }
      }
    }

    redrawSketch();
    //background(255);
    stroke(0);
    strokeWeight(10);
    text(figs.size(), 10, 630);
    for (ArrayList <PVector> f: figs) {
      boolean begin=true;
      float px=0, py=0;
      for (PVector p : f) {
        if (!begin) line(px, py, p.x, p.y);
        begin=false;
        px = p.x;
        py = p.y;
      }
    }
    if (myYesButton.isVisible()) {
      noFill();
      strokeWeight(5);
      stroke(#00ff00, 64);
      rect(minList[0].x, minList[0].y, widthList[0], heightList[0]);
      stroke(#ff0000, 64);
      rect(minList[1].x, minList[1].y, widthList[1], heightList[1]);
      rect(minList[2].x, minList[2].y, widthList[2], heightList[2]);
    }
  }
}

void sendWeightsBroadcast(Server c, float [] w1, float [] w2) {
  // 送： AI:w1 w[0] w[1] w[2] w[3] // ptron1
  // 送： AI:w2 w[0] w[1] w[2] w[3] // ptron2
  if (frameCount % 120 == 59) {
    String send1="AI:w1";
    for (int i=0; i<w1.length; i++) {
      send1 = send1 + " "+w1[i];
    }
    c.write(send1);
    if (debug) println("Send: " + send1);
  } else if (frameCount % 120 == 119) {
    String send2="AI:w2";
    for (int i=0; i<w1.length; i++) {
      send2 = send2 + " "+w2[i];
    }
    c.write(send2);
    if (debug) println("Send: " + send2);
  }
}

void mousePressed() {
  if(mouseButton==LEFT){
    fig = new ArrayList<PVector>();
    figs.add(fig);
  } else if (mouseButton ==RIGHT) {
    if (!figs.isEmpty()) {
      int n=figs.size()-1;
      figs.remove(n);// 最後の要素を消す
      finished=judged=submitted=false;
    }
    print("undo "+figs.size());
  }
}


void mouseDragged() {
  if (mouseButton==LEFT && mouseX<=Rwidth && mouseY<=Rheight) {
    //fig = figs.get(figs.size()-1);
    fig.add(new PVector(mouseX, mouseY));
  }
}

void mouseReleased() {
  //if (mouseButton==LEFT && client != null) {
  //  //描画範囲でマウスが離れて，カウントが3回未満ならdrawCountを増やす
  //  if (mouseX < Rwidth && mouseY < Rheight) {
  //    int n=figs.size()-1;
  //    widthList[n] = maxX-minX;  // w,h of figure
  //    heightList[n] = maxY-minY;
  //    minList[n]=new PVector(minX, minY);
  //  }
  //}
  if (figs.size()>=3) finished=true;
}

void redrawSketch() {
  background(255);
  //グリッド表示
  showGrid();
  //タイトル表示
  textFont(titleFont);
  fill(128);
  textAlign(CENTER, TOP);
  text(displayTitle, width/2-130, 20);
  myJudgeButton.setVisible(finished);
  myJudgeLabel1.setVisible(judged);
  myYesButton.setVisible(judged);
  myNoButton.setVisible(judged);
  myReaction.setVisible(submitted);
  if (judged) {
    float [] x=new float[5];
    x[0]=faceWidth;
    x[1]=faceHeight;
    x[2]=earWidth;
    x[3]=earHeight;
    x[4]=1;
    showX(x);
  }

  showWeightTable(ptron1.getWeights(), ptron2.getWeights());
}


void clearSketch() {
  finished=judged=answered=submitted=false;
  figs.clear();
  // すべての軌跡を消す
  //for (int i=0; i<fig.length; i++) {
  //  fig[i] = new ArrayList <PVector>();
  //}
  redrawSketch();
}

int earHeight, earWidth, faceWidth, faceHeight;
int judge1, judge2;
boolean judged=false;
boolean answered=false;
boolean submitted=false;

void judge() {
  float tmp;
  PVector vtmp;
  float [] size = new float[maxFigs];
  println("into judge");
  //countが3回の場合
  if (!myYesButton.isVisible() && finished) {
    //3つの図形サイズを計算
    for (int i=0; i<figs.size(); i++){
      ArrayList<PVector> f=figs.get(i);
      boolean first=true;
      for (PVector p : f) {
        if (first) {
          minX=maxX=p.x;
          minY=maxY=p.y;
          first=false;
        } else {
          minX=min(minX, p.x);
          minY=min(minY, p.y);
          maxX=max(maxX, p.x);
          maxY=max(maxY, p.y);
        }
        minList[i]=new PVector(minX, minY);
        widthList[i]=maxX- minX;
        heightList[i]=maxY-minY;
        //println(minList[i], widthList[i], heightList[i]);
      }
      println("count="+str(i+1)+" width: "+str(widthList[i])+"px height: "+ str(heightList[i])+"px");
      size[i] = widthList[i]*heightList[i];
    }

    //nの図形を大きい順に並べ替える
    for (int i=0; i<figs.size(); i++) {
      for (int j=i; j<figs.size(); j++) {
        if (size[i] < size[j]) {
          //図形のサイズ
          tmp = size[i];
          size[i] = size[j];
          size[j] = tmp;
          //図形の幅
          tmp = widthList[i];
          widthList[i] = widthList[j];
          widthList[j] = tmp;
          //図形の高さ
          tmp = heightList[i];
          heightList[i] = heightList[j];
          heightList[j]=tmp;
          // 図形外枠
          vtmp=minList[i];
          minList[i]=minList[j];
          minList[j]=vtmp;
        }
      }
    }
    for(int i=0; i<figs.size(); i++){
      println(i, ": fig size", size[i]);
    }
    earHeight =int(((heightList[1]+heightList[2]+grid)/2)/grid+0.5); //耳の高さは両耳の高さの平均
    earWidth = int(((widthList[1]+widthList[2]+grid)/2)/grid+0.5);
    faceWidth = int((widthList[0]+grid/2)/grid+0.5);
    faceHeight = int((heightList[0]+grid/2)/grid+0.5);

    println("顔の幅:"+faceWidth+"   顔の高さ:"+faceHeight+ "  耳の幅:"+earWidth+"  耳の高さ:"+earHeight);
    float [] x=new float[5];

    x[0]=faceWidth;
    x[1]=faceHeight;
    x[2]=earWidth;
    x[3]=earHeight;
    x[4]=1;
    //showX(x);

    judge1=ptron1.feedforward(x);
    judge2=ptron2.feedforward(x);
    showAnswer(ptron1.sum, ptron2.sum);
    myJudgeLabel1.setText("AI1:"+((judge1==1)?"ウサギ":"クマ")+"ですね？");
  }
  judged=true;
}


void showX(float [] x) {
  textFont(normalFont);
  textAlign(RIGHT, CENTER);
  for (int i=0; i<x.length; i++) {
    if (i==posX || i==posY) fill(0);
    else if(EasyMode) fill(255); else fill(128);
    text(""+nf(x[i], 0, 0), 100+100*i, height-60);
  }
}

void showAnswer(float sum1, float sum2) {
  textFont(normalFont);
  textAlign(RIGHT, CENTER);
  fill(0);
  text("判定", 100+100*5, height-80);
  if (EasyMode) text(""+nf(round(sum1), 0, 0), 100+100*5, height-40);
  else text(""+nf(sum1, 0, 3), 100+100*5, height-40);
  text((sum1>0)?"ウサギ":"クマ", 100+100*6, height-40);
  fill(128);
  if (EasyMode) text(""+nf(round(sum2), 0, 0), 100+100*5, height-20);
  else text(""+nf(sum2, 0, 3), 100+100*5, height-20);
  text((sum2>0)?"ウサギ":"クマ", 100+100*6, height-20);
}

void submitYes() {
  if (!submitted) submit(1);
}

void submitNo() {
  if (!submitted) submit(-1);
}

void submit(int answer) {
  submitted=true;
  myReaction.setText("AI1:"+((answer==1) ? "やったー":"ごめんなさいー"));
  String name=cp.get(Textfield.class, "おなまえは？").getText();
  if (name.equals("")) name="noname";
  println("なまえ:"+name);

  if (client != null) {
    // AI1の答えを聞いているのでA1の判定結果を尊重
    String s="AI:t " + name +" "+ faceWidth+" "+faceHeight+" "+ earWidth+" "+ earHeight+" "+(answer*judge1);
    client.write(s);
    println("send:"+s);
  }
}

// クライアントから学習データを受信
// 新たなトレーニングデータとしてcsvおよびTrainerに追加
// クライアントへ現時点での重みデータを送信
import processing.net.*;
import java.net.InetAddress;
import java.net.UnknownHostException;
import java.net.NetworkInterface;
import java.net.SocketException;
import java.util.Enumeration;
//import java.net.ServerSocket;

Server server=null;
Client client=null;


String getIPAddr() {
  try {
    InetAddress addr = InetAddress.getLocalHost();
    String hostAddress = addr.getHostAddress();
    return hostAddress;
  }
  catch(UnknownHostException e) {
    return "";
  }
}


class MyMap {
  PVector r1, r2; // 元の座標
  PVector s1, s2;  // スクリーン座標
  MyMap(PVector _r1, PVector _r2, PVector _s1, PVector _s2) {
    r1=_r1;
    r2=_r2;
    s1=_s1;
    s2=_s2;
  }
  // リアル座標→スクリーン座標変換
  PVector RtoS(float x, float y) {
    return new PVector(
      map(x, r1.x, r2.x, s1.x, s2.x),
      map(y, r1.y, r2.y, s1.y, s2.y));
  }

  // スクリーン座標変換→リアル座標変換
  PVector StoR(float x, float y) {
    return new PVector(
      map(x, s1.x, s2.x, r1.x, r2.x),
      map(y, s1.y, s2.y, r1.y, r2.y));
  }

  //  X区間[rx1,rx2], Y区間[ry1,ry2]のグラフを
  // (sx1,sy1)-(sx2, sy2) のスクリーンに描画
  void myDrawMap(ArrayList <Trainer> training) {
    background(255);

    // タイトル
    fill(0);
    textAlign(CENTER, TOP);
    textFont(titleFont);
    text(displayTitle, width/2, 30);

    float [] w1 = ptron1.getWeights();
    float [] w2 = ptron2.getWeights();
    float y1=(-w1[w1.length-1]-w1[posX]*r1.x)/w1[posY];
    float y2=(-w1[w1.length-1]-w1[posX]*r2.x)/w1[posY];
    if (debug) println(r1.x, y1, r2.x, y2);
    PVector sa = RtoS(r1.x, y1);  // draw threshold
    PVector sb = RtoS(r2.x, y2);
    stroke(0);
    strokeWeight(1);
    line(sa.x, sa.y, sb.x, sb.y);



    strokeWeight(2);
    strokeCap(SQUARE);
    int guess;
    textFont(normalFont);
    textAlign(CENTER, TOP); // ENTER, TOP);
    for (Trainer t : training) {
      guess = ptron1.feedforward(t.x);
      t.show(guess);
    }
    // 凡例
    PVector hanrei=map.RtoS(xmax*0.9, ymax*0.9);
    stroke(0, 0, 255); // ウサギ凡例
    fill(0);
    circle(hanrei.x, hanrei.y, 8);
    textAlign(LEFT, CENTER);
    text("ウサギ", hanrei.x+15, hanrei.y);
    stroke(255, 0, 0); // クマ凡例
    fill(255, 0, 0);
    circle(hanrei.x, hanrei.y+20, 8);
    text("クマ", hanrei.x+15, hanrei.y+20);


    //if (frameCount % 100 == 0) println("---");
    strokeWeight(3);
    stroke(#00ff00);  // green
    strokeCap(ROUND);
    line(s1.x, s1.y, s2.x, s1.y); // X座標の描画
    line(s1.x, s1.y, s1.x, s2.y); // Y座標の描画
    fill(0);
    strokeWeight(0);
    for (int x=0; x<=xmax; x+=5) { // X軸の目盛り
      textAlign(CENTER, TOP);
      PVector p0=RtoS(x, 0);
      PVector p1=RtoS(x, ymax);
      text(x, p0.x, p0.y);
      line(p0.x, p0.y, p1.x, p1.y);
    }
    for (int y=5; y<=ymax; y+=5) { // Y軸の目盛り
      textAlign(RIGHT, CENTER);
      PVector p0=RtoS(0, y);
      PVector p1=RtoS(xmax, y);
      text(y, p0.x, p0.y);
      line(p0.x, p0.y, p1.x, p1.y);
    }
    textAlign(CENTER, TOP);
    text(label[posX], (s1.x+s2.x)/2+20, s1.y+5);
    textAlign(RIGHT, CENTER);
    text(label[posY], s1.x-5, (s1.y+s2.y)/2);
    showWeightTable(w1, w2);
    showJudgementMap();
    //println(label[posX], label[posY]);
  }
}

void showWeightTable(float [] w1, float []w2) {
  textFont(normalFont);
  textAlign(RIGHT, CENTER);
  fill(128);
  text("AI1", 40, height-40);
  if(!EasyMode) text("AI2", 40, height-20);
  for (int i=0; i<w1.length; i++) {
    fill(128);
    if (i!=w1.length-1) text(label[i], 100+100*i, height-80);
    if (EasyMode) {
      //text(""+nf(round(w2[i]*100), 0, 0), 100+100*i, height-20);
    } else {
      text(""+nf(w2[i], 0, 3), 100+100*i, height-20);
    }
    if (i==posX || i==posY || i==w1.length-1) fill(0);
    else if(EasyMode) fill(255); else fill(128);
    if (EasyMode) text(""+nf(round(w1[i]*100), 0, 0), 100+100*i, height-40);
    else text(""+nf(w1[i], 0, 3), 100+100*i, height-40);
  }
}

void showJudgementMap() {
  float [] xx={0, 0, 0, 0, 1};
  int mappingGrid=20;
  noStroke();
  PVector s0=map.RtoS(0, 0);
  PVector s1=map.RtoS(xmax, ymax);
  PVector r;
  //println(s0, s1);
  for (int y=int(s1.y); y<=s0.y; y+=mappingGrid) { // Y軸の目盛り
    for (int x=int(s0.x); x<=s1.x; x+=mappingGrid) { // X軸の目盛り
      r=map.StoR(x, y);
      xx[posX]=r.x;
      xx[posY]=r.y;
      //println(xx);
      int judge=ptron1.feedforward(xx);
      if (judge==1) fill(#0000ff, 10);
      else fill(#ff0000, 10);
      rectMode(CENTER);
      rect(x, y, mappingGrid, mappingGrid);
    }
  }
}


class Perceptron {
  float[] weights;  // Array of weights for inputs
  float c;          // learning constant
  int n;
  float sum;          // 合計値を記録しておく

  // Perceptron is created with n weights and learning constant
  Perceptron(int _n, float c_) {
    n=_n;
    weights = new float[5];
    weights[0]=0;
    weights[1]=0.009;
    weights[2]=0;
    weights[3]=0.07;
    weights[4]=-0.997;
    c = c_;
  }

  // Function to train the Perceptron
  // Weights are adjusted based on "desired" answer
  void train(Trainer t) {
    float [] inputs=t.x;
    int desired=t.answer;
    // Guess the result
    int guess = feedforward(inputs);
    // Compute the factor for changing the weight based on the error
    // Error = desired output - guessed output
    // Note this can only be 0, -2, or 2
    // Multiply by learning constant
    float error = desired - guess;
    // Adjust weights based on weightChange * input
    for (int i = 0; i < weights.length; i++) {
      if (n!=3 && debug) {   // for normal perceptron
        // show error
        if (error==0) print("*");
        else if (error==2) print("+");
        else if (error==-2) print("-");
      }
      if (n==3 && (i!=posX && i!=posY && i!= weights.length-1)) {    // for display perceptron
        continue;
      } else {
        weights[i] += c * error * inputs[i]* random(0.5, 2.0);
      }
    }
  }

  // Guess -1 or 1 based on input values
  int feedforward(float[] inputs) {
    // Sum all values
    sum = 0;
    //if (debug2) print("n="+n+"   ");
    for (int i = 0; i < weights.length; i++) {
      // 表示用パーセプトロンには2値以外は使わない
      if (n==3 && (i!=posX && i!=posY && i!=weights.length-1)) continue;
      if (EasyMode) sum += round(inputs[i])*round(weights[i]*100);
      else sum += inputs[i]*weights[i];
      //if (debug2) print("  "+inputs[i]+"*"+weights[i]);
    }
    //if (debug2) print("   ="+ sum);
    // Result is sign of the sum, -1 or 1
    return activate(sum);
  }

  int activate(float sum) {
    if (sum > 0) return 1;
    else return -1;
  }

  // Return weights
  float[] getWeights() {
    return weights;
  }

  void normalize(float m) {
    float sum=0;
    for (int i=0; i<weights.length; i++) {
      sum+=weights[i]*weights[i];
    }
    for (int i=0; i<weights.length; i++) {
      weights[i]/=sqrt(sum);
      weights[i]*=m;
    }
  }
}


ArrayList <Trainer> training;

class Trainer {
  String name; // add user name
  float[] x;  // x1, x2, ..., xn, bias
  int answer;      //
  int whenCreate;   // 教えてもらった時点でのフレームカウント

  Trainer(String _name, float [] _x, int _a) {
    whenCreate=frameCount;
    name=_name;
    x = _x;
    answer = _a;
  }

  boolean isActive() {
    int diff =frameCount-whenCreate;
    if (diff < 300) return false;
    return true;
  }

  void show(int _guess) {
    PVector u;
    u = map.RtoS(x[posX], x[posY]);
    int diff =frameCount-whenCreate;
    if (!isActive() && (diff / 15) % 2 == 1) {
      //println("diff, t="+diff+" "+(diff/15));
      return ;  // blink 2 times/sec
    }
    if (answer==1) {
      stroke(0, 0, 255); // blue
      fill(0);
    } else {
      stroke(255, 0, 0); // red
      fill(255, 0, 0);
    }
    if (_guess * answer == -1) noFill();
    circle(u.x, u.y, 8);
    text(name, u.x, u.y+5);
  }
}



void createServerGUI() {
  japaneseFont= createFont("monospaced", 18);
  ansFont= createFont("monospaced", 30);
  cp = new ControlP5(this);

  cp.addButton("PrintPicture")
    .setFont(japaneseFont)
    .setCaptionLabel("印刷")
    .setPosition(width-100, height-40)
    .setSize(90, 25)
    .setColorLabel(0)
    .setColorForeground(color(#c0c0c0))
    .setColorBackground(color(#808080));

  cp.addButton("reloadTable")
    .setFont(japaneseFont)
    .setCaptionLabel("リロード")
    .setPosition(width-100, height-70)
    .setSize(90, 25)
    .setColorLabel(0)
    .setColorForeground(color(#c0c0c0))
    .setColorBackground(color(#808080));

  cp.addButton("resetTable")
    .setFont(japaneseFont)
    .setCaptionLabel("リセット")
    .setPosition(width-100, height-100)
    .setSize(90, 25)
    .setColorLabel(0)
    .setColorForeground(color(#c0c0c0))
    .setColorBackground(color(#808080));

  cp.addRadioButton("selectX")
    .setFont(japaneseFont)
    .setPosition(width-400, height-60)
    .setSize(20, 20)
    .setColorLabel(0)
    .setItemsPerRow(4)
    .setSpacingColumn(50)
    .addItem("XFW", 0)
    .addItem("XFH", 1)
    .addItem("XEW", 2)
    .addItem("XEH", 3)
    .activate(posX);

  cp.addRadioButton("selectY")
    .setFont(japaneseFont)
    .setPosition(width-400, height-30)
    .setSize(20, 20)
    .setColorLabel(0)
    .setItemsPerRow(4)
    .setSpacingColumn(50)
    .addItem("YFW", 0)
    .addItem("YFH", 1)
    .addItem("YEW", 2)
    .addItem("YEH", 3)
    .activate(posY);
}


void createClientGUI() {
  japaneseFont= createFont("monospaced", 18);
  ansFont= createFont("monospaced", 30);

  //絵をクリアするボタン
  cp = new ControlP5(this);


  cp.addButton("PrintPicture")
    .setFont(japaneseFont)
    .setCaptionLabel("印刷")
    .setPosition(width-100, height-40)
    .setSize(90, 30)
    .setColorLabel(0)
    .setColorForeground(color(#c0c0c0))
    .setColorBackground(color(#808080));
  cp.addButton("clearSketch")
    .setFont(japaneseFont)
    .setCaptionLabel("けす")
    .setPosition(Rwidth+(240-100)/2, 20)
    .setSize(100, 40)
    .setColorForeground(color(#c0c0c0))
    .setColorBackground(color(#808080));

  //パーセプトロンに入力値を送るボタン
  myJudgeButton=cp.addButton("judge")
    .setFont(japaneseFont)
    .setCaptionLabel("ＡＩはんてい")
    .setPosition(Rwidth+(240-120)/2, 280)
    .setSize(120, 60)
    .setColorForeground(color(#c0c0c0))
    .setColorBackground(color(#808080));

  cp.addTextfield("おなまえは？")
    .setPosition(Rwidth+(240-200)/2, 200)
    .setSize(200, 40)
    .setColorCaptionLabel(#000000)
    .setFont(japaneseFont)
    .setFocus(true)
    .setColorBackground(color(#ffffff))
    .setColor(#000000) ;

  myJudgeLabel1 = cp.addTextlabel("judgement1")
    .setText("AI1:")
    .setPosition(Rwidth+(240-200)/2, 400)
    .setColor(#ff8000)
    .setVisible(false)
    .setFont(japaneseFont) ;

  myYesButton = cp.addButton("submitYes")
    .setFont(japaneseFont)
    .setCaptionLabel("はい")
    .setPosition(Rwidth+(240-200)/2-10, 450)
    .setSize(100, 80)
    .setVisible(false)
    .setColorForeground(color(#c0c0c0))
    .setColorBackground(color(#808080));

  myNoButton = cp.addButton("submitNo")
    .setFont(japaneseFont)
    .setCaptionLabel("いいえ")
    .setPosition(Rwidth+(240)/2+10, 450)
    .setSize(100, 80)
    .setVisible(false)
    .setColorForeground(color(#c0c0c0))
    .setColorBackground(color(#808080));

  myReaction = cp.addTextlabel("reaction")
    .setText("リアクション")
    .setPosition(Rwidth+(240-200)/2, 600)
    .setColor(#ff8000)
    .setVisible(false)
    .setFont(ansFont) ;

  // create a toggle
  myEasyMode = cp.addToggle("EasyMode")
    .setPosition(width-100, height-100)
    .setFont(japaneseFont)
    .setColorLabel(#000000)
    .setSize(50, 20)
    .setMode(ControlP5.SWITCH)
    .setValue(true)
    ;
}
 
