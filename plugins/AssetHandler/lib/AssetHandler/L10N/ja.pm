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
	'Unlink' => '登録削除',
	'Associated Objects' => '関連記事',
	'MIME Media Type' => 'MIMEタイプ',
	'ParentID' => '親ID',
	'Asset associated with no objects' => '関連付けされていないアイテム',
);

1;

