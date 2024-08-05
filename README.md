# immich-ruby

This script exports Album from Immich. 

I use this to export my favorite Albums and copy them to my Android for zero latency and offline browse.

```
ruby immich.rb -a Hawaii
```

This script will connect to the Immich defined at ~/.config/immich/auth.yml. 

```
instanceUrl: http://immich.local:2283
apiKey: 
```

Use `-a` to set the Album you want to export.

The code exports photos by 3 steps:

1. Download each assets by zip
2. Unzip them
3. Rename assets based on EXIF

The final results is in "downloads/:album_name/flatten/"




