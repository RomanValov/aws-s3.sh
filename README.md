# Shell scripts to access AWS S3

1. Install dependencies:

```
    apt-get install html-xml-utils curl
```

2. To download single file:

```
    ./aws-s3-file.sh <region> <bucket> <remote-file> <local-file>
```

3. To sync local directory:

```
    ./aws-s3-sync.sh <region> <bucket> <remote-path> <local-path>
```
