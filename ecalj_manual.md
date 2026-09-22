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

- POSCAR 形式から ctrls 形式への変換
  ```
  vasp2ctrl gaas
  ```
- 入力ファイルである ctrlgen.toml の出力
  ```
  ctrlgenToml.py gaas
  ```
- ctrlg.toml の編集
  ```
  [bz]
  nkabc  = [8, 8, 8]  # k-mesh divisions
  [ham]
  xcfun       = 1  # 1=VWN, 2=Barth-Hedin, 103=PBE-GGA
  scaledsigma = 1.0  # QSGW mixing: 1.0 full, 0.8 = QSGW80
  [gw]
  n1n2n3 = [4, 4, 4]   # BZ mesh
  ```
  - 磁性体の場合
  ```
  [ham]
  nspin       = 1  # 1 nonmag, 2 spin-polarized
  ```
  - LDA+U する場合
  - VCA する場合
  - 金属バンドを計算する場合 (QSGWをする際の自己無撞着性の設定)
    ```
    [iter]
    mix   = "B3"  # B3 = Broyden hist=3 (default); A3 = Anderson hist=3
    b     = 0.2  # mixing ratio (smaller -> more stable)
    ```
- lmfa の実行
  ```
  mpirun -np 1 lmfa gaas
  ```
  - 注意! ohtaka では mpirun として実行しないとエラーになるので注意

  
## DFT 実行
- lmf の実行
  - `vi lmf.sh` と入力して `lmf.sh` ファイルを作成。そこに以下の1行を記述します。
    ```
    mpirun -np 4 lmf gaas
    ```
  - 保存したら計算ノードにて実行します (実行コマンドは各自使用している計算機に応じて変更すること)
    ```
    (ohtakaの場合)  sbatch lmf.sh
    (pegasusの場合) qsub lmf.sh
    ```
  - lmf というのが通常の DFT 計算に相当します。ここで基底状態の電子密度を計算します。ここの計算は少し時間がかかるのでログインノードで実行せず、必ず計算ノードで実行するようにしましょう。
- バンド計算の実行
  - lmf による電子密度計算が終わったらバンド計算を実行します。この後の QSGW を行うのに絶対必要なわけではないですが、DFT の段階でうまく計算ができているか確認するためにもバンドはチェックしておきましょう。
  - getsyml の実行: 
    ```
    getsyml gaas
    ```
  - job_band の実行
    ```
    job_band gaas -np 4
    ```
## QSGW 実行
- 最後に QSGW を行います。
  ```
  gwsc -np 8 1 gaas
  ```
## Wannier化
- window の設定: 以下のような部分を ctrlg.toml から探してください。その上でコメントアウトをはずします。
  ```
  # ----- Wannier (uncomment to use) -----
  # wan_out_emin  = -1.05   # eV relative to EFermi
  # wan_out_emax  =  2.4
  # wan_maxit_1st = 300
  # wan_conv_1st  = 1e-7
  # wan_max_1st   = 0.1
  # wan_maxit_2nd = 1500
  # wan_max_2nd   = 0.3
  # wan_conv_end  = 1e-8
  ```
  - 各種の値の意味は Wannier90 を同様の意味なので省略
  - ただしエネルギーの値は Fermi level を 0 となっていて、Wannier90 とは定義が異なっていることに注意
  - コメントになっている `# eV relative to EFermi` は削除しないと動かないので注意
- 軌道の選択: 同様に以下のような部分を探してください。Worbという部分が軌道選択の箇所です。
  ```
  # Worb: atomic orbitals for MLWF / MLO modelling.
  # Each row: <iatom> <label> <lm1> <lm2> ...
  # lm index: 1=s, 2=py, 3=pz, 4=px, 5=xy, 6=yz, 7=3z^2-1, 8=xz, 9=x^2-y^2, ... (real harmonics)
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