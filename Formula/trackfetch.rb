class Trackfetch < Formula
  desc "Turn a text file of songs into tagged MP3s with Spotify metadata"
  homepage "https://github.com/ByteMe6/trackfetch"
  license "GPL-3.0-or-later"

  on_macos do
    on_arm do
      url "https://github.com/ByteMe6/trackfetch/releases/download/v2.3.3/trackfetch-macos-arm64"
      sha256 "8381fb81f0a3c35a288df6acbdceda90f03d3dd9b59d3b1b2c6071f8a858746a"
    end

    on_intel do
      url "https://github.com/ByteMe6/trackfetch/releases/download/v2.3.3/trackfetch-macos-x86_64"
      sha256 "baa7a4616c64ed8123e42f48f5659234a45d16f0db6d03fe6daad0b1e533012b"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/ByteMe6/trackfetch/releases/download/v2.3.3/trackfetch-linux-arm64"
      sha256 "300f36e35fde205b7ba6d692e60cc98e2c9187ad5b2656586e7fe873c8574ed3"
    end

    on_intel do
      url "https://github.com/ByteMe6/trackfetch/releases/download/v2.3.3/trackfetch-linux-x86_64"
      sha256 "e0259548cffc1267e76db4f1c7cc84c39139d286e0912da8ae422695b4d3be9e"
    end

    depends_on "ffmpeg"
  end

  depends_on "deno"
  depends_on "pillow"
  depends_on "yt-dlp"

  # ffmpeg is the formula Homebrew most often has to build from source, and a
  # source build takes hours. On macOS the upstream static binary is installed
  # inside the formula instead, so `brew install` never compiles it.
  on_macos do
    on_arm do
      resource "ffmpeg" do
        url "https://github.com/eugeneware/ffmpeg-static/releases/download/b6.1.1/ffmpeg-darwin-arm64.gz"
        sha256 "8923876afa8db5585022d7860ec7e589af192f441c56793971276d450ed3bbfa"
      end
    end

    on_intel do
      resource "ffmpeg" do
        url "https://github.com/eugeneware/ffmpeg-static/releases/download/b6.1.1/ffmpeg-darwin-x64.gz"
        sha256 "929b375c1182d956c51f7ac25e0b2b0411fb01f6f407aa15c9758efeb4242106"
      end
    end
  end

  def install
    libexec.install Dir["trackfetch-*"].first => "trackfetch"

    binaries = [libexec/"trackfetch"]

    if OS.mac?
      resource("ffmpeg").stage do
        # Homebrew unpacks single-file .gz resources on some versions and
        # leaves them alone on others, so handle both.
        binary = Dir["ffmpeg-darwin-*"].first
        if binary.end_with?(".gz")
          system "gunzip", binary
          binary = binary.delete_suffix(".gz")
        end
        libexec.install binary => "ffmpeg"
      end

      binaries << libexec/"ffmpeg"
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
      On macOS, ffmpeg is installed inside the formula and is not linked into
      your PATH; trackfetch uses it automatically. yt-dlp and deno come from
      Homebrew as usual.
    EOS
  end

  test do
    assert_match "usage: trackfetch", shell_output("#{bin}/trackfetch --help")

    if OS.mac?
      assert_match "ffmpeg version", shell_output("#{libexec}/ffmpeg -version")
    end

    assert_predicate Formula["yt-dlp"].opt_bin/"yt-dlp", :exist?
    assert_predicate Formula["deno"].opt_bin/"deno", :exist?
  end
end
