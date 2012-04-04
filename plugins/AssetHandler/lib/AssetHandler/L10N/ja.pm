package AssetHandler::L10N::ja;

use strict;
use base 'AssetHandler::L10N::en_us';
use vars qw( %Lexicon );

## The following is the translation table.

%Lexicon = (
	'AssetHandler allows you to mass import and manage assets in Movable Type' => 'AssetHandlerは、アイテムの大量インポートと一括編集機能をMovableTypeに追加します。',
	'Import Assets' => 'アイテムのインポート',
	'Batch Edit Assets' => 'アイテムを一括編集する',
	'Enter the full path to the file (or directory) you wish to Import' => 'インポートするパスを入力してください。',
	'Enter a corresponding URL for the above path' => '上で入力したパスに対応する、URLを入力してください。',
	'The path you have entered is a directory. Would you like to proceed?' => '入力したパスはディレクトリーです。すべてのファイルをインポートしますか？',
	'Yes, Import all the files in [_1]' => 'はい、[_1]の中のファイルをすべてインポートします。',
	'No, I would like to choose the files to Import' => 'いいえ、インポートするファイルを選択します。',
	'No, I would like to only Import files with a particular extension' => 'いいえ、インポートするファイルの拡張子を指定します。',
	'Importing files into assets in blog' => 'アイテムをブログにインポート中です。',
	'File Name' => 'ファイル名',
	'Import' => 'インポート',
	'Unlink' => '登録解除',
	'Batch Edit' => '一括編集',
	'Associated Objects' => '関連記事',
	'MIME Media Type' => 'MIMEタイプ',
	'Parent AssetID' => '親アイテムID',
	'Asset associated with no objects' => '関連付けされていないアイテム',
	'Created Time' => '作成時刻',
	'Modified Time' => '更新時刻',
	'Pixels' => 'ピクセル数',
	'FullPath to %r' => 'ブログパスを「%r」に変更',
	'Flatten Path' => 'ブログパスをフルパスに展開',
	'Fix wrong URL from Path' => 'URLをファイルパスに合わせて修正',
	'Modify File Path' => 'ファイルパス値を変更する',
	'Move Assets' => 'アイテムを移動する',
	'Specify a folder relative to the blog site path/URL to move the selected asset(s) to. Examples: enter a single folder ("assets/"), enter a subdirectory path ("my/asset/location/"), or move assets to the blog root with "/".'
		=> '選択したアイテムの移動先を、ブログパス/URLからの相対パスで指定してください。 例: トップフォルダー ("assets/") サブディレクトリ ("my/asset/location/") ブログルート ("/")',
	'Specify a folder relative to the blog site path/URL to modify the selected asset(s) path to. Examples: enter a single folder ("assets/"), enter a subdirectory path ("my/asset/location/"), or modify assets to the blog root with "/".'
		=> '選択したアイテムのパスの変更先を、ブログパス/URLからの相対パスで指定してください。 例: トップフォルダー ("assets/") サブディレクトリ ("my/asset/location/") ブログルート ("/")',
	'The selected asset(s) has been successfully moved. Be sure to republish and double-check for any existing use of the old URL!'
		=> '選択したアイテムは移動されました。再構築を行い再度以前のURLを使用している箇所がないか確認をしてください。',
	'Some selected asset(s) has <em>not</em> been moved. The selected asset(s) are not file-based or are missing.'
		=>'選択したアイテムの移動に<em>失敗しました</em>。ファイルが見つかりませんでした。',
	'Fix AssetDatas' => 'アイテムデータを自動修正する',
	'Rename Assets' => 'アイテムのファイル名を変更する',
	'Specify a filename to rename the selected asset(s) to. Examples: examples.jpg or examples.'
		=> '選択したアイテムの変更する名前を入力してください。 例: examples.jpg または example',
	'Make Entry (with Category)' => 'ブログ記事を作成する（カテゴリーと共に）',
	'Category Label:' => 'カテゴリー名:',
	'Category Basename:' => 'カテゴリーベースネーム:',
	'Modified On' => '修正日',
	'FileSize' => 'ファイルサイズ',
	'This asset has not been used.' => 'アイテムは利用されていません。',
);

1;

