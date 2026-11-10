///|
extern "js" fn arguments() -> FixedArray[String] =
  #| () => process.argv.slice(2)

///|
extern "js" fn read_input(path : String) -> FixedArray[String] =
  #| path => {
  #|   try {
  #|     const fs = process.getBuiltinModule("node:fs");
  #|     const fd = fs.openSync(path, "r");
  #|     try {
  #|       const limit = 8_000_000;
  #|       const stat = fs.fstatSync(fd);
  #|       if (!stat.isFile() || stat.size > limit) return ["Expected a file of at most 8 MB", ""];
  #|       const bytes = Buffer.alloc(stat.size + 1);
  #|       let size = 0;
  #|       while (size < bytes.length) {
  #|         const count = fs.readSync(fd, bytes, size, bytes.length - size, null);
  #|         if (!count) break;
  #|         size += count;
  #|       }
  #|       if (size !== stat.size) return ["File size changed during the read; retry", ""];
  #|       return ["", new TextDecoder("utf-8", {fatal: true}).decode(bytes.subarray(0, size))];
  #|     } finally {
  #|       fs.closeSync(fd);
  #|     }
  #|   } catch (error) {
  #|     return [error.code || "Unable to read a UTF-8 file", ""];
  #|   }
  #| }

///|
extern "js" fn stderr(message : String) -> Unit =
  #| message => console.error(message)

///|
extern "js" fn write_new_file(path : String, content : String) -> String =
  #| (path, content) => {
  #|   const fs = process.getBuiltinModule("node:fs");
  #|   let fd;
  #|   try {
  #|     fd = fs.openSync(path, "wx");
  #|     try {
  #|       fs.writeFileSync(fd, content, "utf8");
  #|     } finally {
  #|       fs.closeSync(fd);
  #|     }
  #|     return "";
  #|   } catch (error) {
  #|     if (fd !== undefined) {
  #|       try { fs.unlinkSync(path); } catch {}
  #|     }
  #|     return error.code || "Unable to write a UTF-8 file";
  #|   }
  #| }

///|
extern "js" fn set_status(status : Int32) -> Unit =
  #| status => { process.exitCode = status; }
