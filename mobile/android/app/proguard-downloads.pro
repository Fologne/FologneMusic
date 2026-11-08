# Commons Compress constructs registered ZIP extra fields through reflection.
-keep,allowobfuscation class * implements org.apache.commons.compress.archivers.zip.ZipExtraField {
    public <init>();
}
