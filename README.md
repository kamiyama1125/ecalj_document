# ecalj manual

## install

### python のインストール
- ecalj インストールのためには、事前に python を計算機に導入する必要があります。  公式マニュアルでは pyenv を使った方法が推奨されていますが、筆者の環境では pyenv を使うとうまく ecalj を実行することができませんでした。東大物性研のスパコン ohtaka には python がプリインストールされていますが、バージョンが古いため、やはり自分で python を導入する必要があります。
- 筆者は代わりに mise というツールを用いて python を導入することで ecalj を実行することに成功しました。以下では mise を用いた python のインストール方法を説明します。

- まず mise をインストールします。
  ```
  curl https://mise.run | sh
  ```
- 続いて ecalj を実行するためのディレクトリを作成し、そのディレクトリに移動します。ここでは ecalj_dir という名前に設定。
  ```
  mkdir ~/ecalj_dir
  cd ~/ecalj_dir
  ```
- ディレクトリ移動したら、以下を実行して python をインストールします。
  ```
  mise install python@3.14.3
  mise use python@3.14.3
  ```
- 以下を実行してエラーが出なければインストール成功です。
  ```
  python --version
  ```
- ecalj 実行に必要な python ライブラリを事前にインストールしておきます。
  ```
  pip install --upgrade pip
  pip install numpy pandas seekpath spglib pymatgen mp-api scipy plotly cif2cell
  ```

### ecalj のインストール
- まずは事前にこのコマンドを実行します。
  ```
  source /opt/intel/oneapi/setvars.sh
  ```
  - 今後 ecalj を実行していく上で、なぜか実行ができなくなった場合には、このコマンドを入力することで解決することがあります。
  
- ecalj_dir に移動して ecalj をダウンロードして解凍します。
  ```
  cd ~/ecalj_dir
  git clone https://github.com/tkotani/ecalj.git
  ```
  すると `ecalj` というソースコード等が入ったディレクトリがその中にできます。（ディレクトリ構造としては以下のようなイメージ）
  ```
  ecalj_dir/
  └─ ecalj/
  ```
- `ecalj` ディレクトリに入ってから、インストールのコマンドを実行します。するとインストールとテストが自動で始まります。インストールが正常にできていれば 10 分くらいでテスト計算が終わります。
  ```
  cd ecalj
  ./InstallAll.py --fc ifort
  ```
## 計算準備 
ここからは実際に計算を行っていく手順を説明していきます。流れとしては計算実行のための準備ファイルの生成 → DFT 計算の実行 → QSGW 計算の実行という流れです。

#### step1: POSCAR 形式から ctrls 形式への変換
  - ecalj では `ctrls` という形式の結晶構造ファイルを用いるので、結晶構造データを用意する必要があります。VASP の `POSCAR` 形式でデータを用意している場合、ecalj には POSCAR から ctrls に変換するコマンドがあるので、それを用います。
  ```
  (コマンド実行)
  vasp2ctrl gaas
  ```
#### step2: 入力ファイル ctrlg.XXX.toml の作成
  ```
  (コマンド実行)
  ctrlgenToml.py gaas
  ```
  これを実行するとたくさんファイルが出力されるのですが、その中の `ctrlg.GaAs.toml` というファイルが重要で、このファイルをいじることになります (VASPでいうINCARに相当)。
  - この段階でよくエラーが出ます。だいたいエラーメッセージは以下のようになっています。
    ```
    (ターミナルの表示)
    ctrlgenToml: lmchk --getwsr failed; see llmchk_getwsr
    ```
    その場合には先述の通り、
    ```
    (コマンド実行)
    source /opt/intel/oneapi/setvars.sh
    ```
    を入力することで解決することがあります。
#### step3: ctrlg.XXX.toml の編集
  では `ctrlg.GaAs.toml` の中身を開いて必要な部分を編集していきます。ファイルを開くとたくさんの情報が書かれていますが、ユーザーが操作するべき点は以下の4点です。
  ##### 1. DFT の 波数メッシュ (k-mesh) の設定
  まずは DFT 計算における波数メッシュです。以下の部分を探してください。
  ```
  (ctrlg.tomlの中身)
  [bz]
  nkabc  = [8, 8, 8]  # k-mesh divisions
  ```
  デフォルトでは 8x8x8 になっています。ここを適宜使いたい波数メッシュに変更してください（この部分はVASPとかでやる通常のDFTと同様です）。
  ##### 2. 交換相関汎函数の設定
  次に交換相関汎函数です。VASP で PBE とか PBEsol とか言っている箇所です。以下の部分を探してください（中略とあるのは間にいくつか行がはさまっている、という意味）
  ```
  (ctrlg.tomlの中身)
  [ham]
    ( 中 略 )
  xcfun       = 1  # 1=VWN, 2=Barth-Hedin, 103=PBE-GGA
  ```
  デフォルトでは `xcfun=1` となっていて VMN (LDA近似による汎函数の一つ) となっています。ここは `xcfun=103` : PBE-GGA に変更しましょう (それで VASPにおけるデフォルトと同様の設定になる)。
  ##### 3. DFT と QSGW の混ぜ率の設定
  ここからは QSGW 特有の設定です。まず以下の項目を探してください。
  ```
  (ctrlg.tomlの中身)
  [ham]
    ( 中 略 )
  scaledsigma = 1.0  # QSGW mixing: 1.0 full, 0.8 = QSGW80
  ```
  これは QSGW 計算をする際の DFT と QSGW の混ぜ率です。LDA法はバンドギャップを過小評価してしまうという問題が知られています。QSGW法はLDAと比べるとバンドギャップを正確に評価できますが、そのままだと今度は実際のギャップサイズよりも過大評価してしまう、という問題が存在します。ecaljでは LDA と QSGW の間をとって QSGW 80% + LDA 20% の比率で混ぜることによって実験に近いバンドギャップを再現するという「QSGW80法」が採用されています (80% という値は開発者の小谷先生が経験的な考えた割合であるようです)。デフォルトでは `scaledsigma = 1.0`: 純粋な QSGW となっているので、QSGW80 法を用いるために `scaledsigma = 0.8` と設定しましょう。

  ##### 4. QSGW の波数メッシュ (q-mesh) の設定
  DFT (電荷密度計算) の 波数メッシュとは別に、QSGW における波数メッシュを決める必要があります。ここでいう端数というのは、QSGW 法における準粒子の波数メッシュです。
  ```
  (ctrlg.tomlの中身)
  [gw]
  n1n2n3 = [4, 4, 4]   # BZ mesh
  ```
  デフォルトでは 4x4x4 となっています。この値を大きくすると、計算量が急速に大きくなっていきます。というのも、各準粒子の波数点 (q点) ごとに、電荷密度に対する波数メッシュ (k-mesh) が実行されるためです。なのでいきなり大きくするのではなく、計算量とバンドの形の変化を見ながら少しずつ q-mesh を大きくしていき、これ以上 q-mesh を大きくしてもバンドの形が大きく変わらない、というポイントを見つけるのが良いでしょう。
  - 絶縁体だと比較的メッシュが粗くてもよいようです（もちろん調べたい物質ごとに検証は必要）。一方で金属の場合は比較的多めにq-meshが必要なようです。
  - 具体例として、星さんの La2PdO4 の QSGW 計算では q-mesh: 8x8x8 をとっていたようです。
  
以上が常に設定すべき点となります。そのほかに計算の状況に応じて別途必要な設定については以下の記事をご覧ください。

#### step4: lmfa の実行
  ctrlg.toml ファイルの設定ができたら `lmfa` コマンドを実行します。これは初期電子状態を計算するための対称性を計算しているようです。
  ```
  (コマンド実行)
  mpirun -np 1 lmfa gaas
  ```
  【注意】 公式マニュアルには書かれていませんが、ohtaka では mpirun として実行しないとエラーになるので注意してください。また、繰り返しですがエラーが出た際は `source /opt/intel/oneapi/setvars.sh` を試してください。

  
## DFT 実行
#### lmf の実行
  - `vi lmf.sh` と入力して `lmf.sh` ファイルを作成。`lmf.sh` ファイルの中で以下のコマンドを記載するようにしてください。([lmf.sh のサンプル](./scripts_for_ohtaka/lmf.sh))
    ```
    mpirun -np 8 lmf GaAs
    ```
  - 保存したら計算ノードにて実行します (実行コマンドは各自使用している計算機に応じて変更すること。以降はohtakaの場合を想定して sbatch コマンドの方のみ記載します。)
    ```
    (ohtakaの場合)  sbatch lmf.sh
    (pegasusの場合) qsub lmf.sh
    ```
  - lmf というのが通常の DFT 計算に相当します。ここで基底状態の電子密度を計算します。ここの計算は少し時間がかかるのでログインノードで実行せず、必ず計算ノードで実行するようにしましょう。
#### バンド計算の実行
  lmf による電子密度計算が終わったらバンド計算を実行します。この後の QSGW を行うのに絶対必要なわけではないですが、DFT の段階でうまく計算ができているか確認するためにもバンドはチェックしておきましょう。
  ##### getsyml の実行
  対称性の判定と k-path の自動生成をしてくれます。
  ```
  getsyml GaAs
  ```
  ##### job_band の実行
  以下のコマンドによってバンド計算を実行できます。
  ```
  job_band GaAs -np 4
  ```
  これは少し時間かかるので、計算ノードで実行するようにしましょう。[job_band.sh のサンプル](./scripts_for_ohtaka/job_band.sh)を参考にスクリプトファイルを作り、`sbatch job_band.sh` を実行することで計算ノードで実行することができます。
  ##### バンドの描画について
  バンドの描画についてですが、ecalj のデフォルト機能として gnuplot で描画するためのファイルが出力されています。以下のコマンドで gnuplot を実行するとバンドが描画されます。
  ```
  gnuplot -p 
  ```
## QSGW 実行
- 最後に QSGW を行います。
  ```
  gwsc -np 8 1 GaAs
  ```
## Wannier化
- window の設定: 以下のような部分を ctrlg.toml から探してください。その上でコメントアウトをはずします。
  ```
  #----- Wannier (uncomment to use) -----
  #wan_out_emin  = -1.05   # eV relative to EFermi
  #wan_out_emax  =  2.4
  #wan_maxit_1st = 300
  #wan_conv_1st  = 1e-7
  #wan_max_1st   = 0.1
  #wan_maxit_2nd = 1500
  #wan_max_2nd   = 0.3
  #wan_conv_end  = 1e-8
  ```
  - 各種の値の意味は Wannier90 を同様の意味なので省略
  - ただしエネルギーの値は Fermi level を 0 となっていて、Wannier90 とは定義が異なっていることに注意
  - コメントになっている `# eV relative to EFermi` は削除しないと動かないので注意
- 軌道の選択: 同様に以下のような部分を探してください。Worbという部分が軌道選択の箇所です。
  ```
  #Worb: atomic orbitals for MLWF / MLO modelling.
  #Each row: <iatom> <label> <lm1> <lm2> ...
  #lm index: 1=s, 2=py, 3=pz, 4=px, 5=xy, 6=yz, 7=3z^2-1, 8=xz, 9=x^2-y^2, ... (real harmonics)
  Worb = """
  ! 1 Ga   1 2 3 4 5 6 7 8 9
  ! 2 As   1 2 3 4 5 6 7 8 9
  """
  ```
  - 例えば Ga の p 軌道だけをモデル化したかったら、以下のようにします。
    ```
    Worb = """
     1 Ga   2 3 4
    """
    ```
- 設定できたら `genMLWF.sh` というファイルを作って以下のように設定
  ```
  genMLWF gaas -np 4
  ```
  計算ノードで実行する
  ```
  sbatch genMLWF.sh
  ```
- なお、私がohtakaで実行した際にはgenMLWFでエラーが発生しました。ソースコードのバグのようでして、以下の手順でソースコードを修正すると動くようになりました。
  genMLWFのソースコードは以下のディレクトリに存在しています。
  ```
  ~/bin/genMLWF
  ```
  そこの17行目にある
  ```
  NO_MPI=0
  ```
  という行を `NO_MPI=1` と書き換えることで動くようになりました。