class Trackfetch < Formula
  desc "Turn a text file of songs into tagged MP3s with Spotify metadata"
  homepage "https://github.com/trackfetch/trackfetch"
  license "GPL-3.0-or-later"

  on_macos do
    on_arm do
      url "https://github.com/trackfetch/trackfetch/releases/download/v2.4.0/trackfetch-macos-arm64"
      sha256 "88e0dfc9c5d2aa0f8ac84d780312bcdc5c5ef47d37bb1290a1a65051b035221e"
    end

    on_intel do
      url "https://github.com/trackfetch/trackfetch/releases/download/v2.4.0/trackfetch-macos-x86_64"
      sha256 "6f3d6c35c7a6a05f3cb4325185baea49d3c5f90c59a450834d0e780df2beaabc"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/trackfetch/trackfetch/releases/download/v2.4.0/trackfetch-linux-arm64"
      sha256 "0c6ebabee8e3b356efa502a8bf26f54b5ea6a6deb90a8973dd7f24538535b46a"
    end

    on_intel do
      url "https://github.com/trackfetch/trackfetch/releases/download/v2.4.0/trackfetch-linux-x86_64"
      sha256 "98fa311024a8dc95261119a6a01ef26dc7df302ee7268640dd6eb29fc488475d"
    end

    depends_on "ffmpeg"
  end

  depends_on "deno"
  depends_on "pillow"
  depends_on "yt-dlp"

  # ffmpeg is the formula Homebrew most often has to build from source, and a
  # source build takes hours. On macOS the upstream static binaries are
  # installed inside the formula instead, so `brew install` never compiles it.
  # trackfetch checks for both ffmpeg and ffprobe at startup, so both are
  # bundled; the upstream releases ship them separately.
  on_macos do
    on_arm do
      resource "ffmpeg" do
        url "https://github.com/eugeneware/ffmpeg-static/releases/download/b6.1.1/ffmpeg-darwin-arm64.gz"
        sha256 "8923876afa8db5585022d7860ec7e589af192f441c56793971276d450ed3bbfa"
      end

      resource "ffprobe" do
        url "https://github.com/eugeneware/ffmpeg-static/releases/download/b6.1.1/ffprobe-darwin-arm64.gz"
        sha256 "d986a8ec7b030899fe66a8a288ed809a3543338705a3ce178cfb85869c5d80be"
      end
    end

    on_intel do
      resource "ffmpeg" do
        url "https://github.com/eugeneware/ffmpeg-static/releases/download/b6.1.1/ffmpeg-darwin-x64.gz"
        sha256 "929b375c1182d956c51f7ac25e0b2b0411fb01f6f407aa15c9758efeb4242106"
      end

      resource "ffprobe" do
        url "https://github.com/eugeneware/ffmpeg-static/releases/download/b6.1.1/ffprobe-darwin-x64.gz"
        sha256 "d4da574d6e2e197bd259b47d69cf262df9e312af24ad960444f6d806d3d4c186"
      end
    end
  end

  def install
    libexec.install Dir["trackfetch-*"].first => "trackfetch"

    binaries = [libexec/"trackfetch"]

    if OS.mac?
      { "ffmpeg" => "ffmpeg", "ffprobe" => "ffprobe" }.each do |name, target|
        resource(name).stage do
          # Homebrew unpacks single-file .gz resources on some versions and
          # leaves them alone on others, so handle both.
          binary = Dir["#{name}-darwin-*"].first
          if binary.end_with?(".gz")
            system "gunzip", binary
            binary = binary.delete_suffix(".gz")
          end
          libexec.install binary => target
        end

        binaries << libexec/target
      end
    end

    binaries.each do |binary|
      # Downloads do not keep the executable bit.
      binary.chmod 0755

      # Apple Silicon only runs signed code and the upstream builds are not signed.
      system "codesign", "--force", "--sign", "-", binary if OS.mac? && Hardware::CPU.arm?
    end

    # trackfetch runs yt-dlp, ffmpeg and deno from PATH. The wrapper puts the
    # bundled copies in front of it, so the formula works on a bare system.
    (bin/"trackfetch").write <<~SH
      #!/bin/sh
      PATH="#{libexec}:$PATH"
      export PATH
      exec "#{libexec}/trackfetch" "$@"
    SH
    chmod 0755, bin/"trackfetch"
  end

  def caveats
    return unless OS.mac?

    <<~EOS
      On macOS, ffmpeg and ffprobe are installed inside the formula and are not
      linked into your PATH; trackfetch uses them automatically. yt-dlp and deno
      come from Homebrew as usual.
    EOS
  end

  test do
    assert_match "usage: trackfetch", shell_output("#{bin}/trackfetch --help")

    if OS.mac?
      assert_match "ffmpeg version", shell_output("#{libexec}/ffmpeg -version")
      assert_match "ffprobe version", shell_output("#{libexec}/ffprobe -version")
    end

    assert_predicate Formula["yt-dlp"].opt_bin/"yt-dlp", :exist?
    assert_predicate Formula["deno"].opt_bin/"deno", :exist?
  end
end
