# capy-template
Simple template for a Capy app

## Building

On first build, don't forget to ensure [zigmod](https://github.com/nektro/zigmod/releases/latest)
is downloaded and installed on your machine. Then, run:
```sh
zigmod fetch
```
And you're ready to go!

Then if you wish to run the app simply execute
`zig build run` (`zigmod fetch` is no longer required)

In the same way, to build and run the app for WebAssembly, execute
`zig build serve`
