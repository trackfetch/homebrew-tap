class Trackfetch < Formula
  desc "Turn a text file of songs into tagged MP3s with Spotify metadata"
  homepage "https://github.com/trackfetch/trackfetch"
  license "GPL-3.0-or-later"

  on_macos do
    on_arm do
      url "https://github.com/trackfetch/trackfetch/releases/download/v2.3.4/trackfetch-macos-arm64"
      sha256 "341e04a26ddc2435402ed0d70689ab80e9153d886527ac23330a64a935b39c81"
    end

    on_intel do
      url "https://github.com/trackfetch/trackfetch/releases/download/v2.3.4/trackfetch-macos-x86_64"
      sha256 "757733338ecebfb2e36c3df0b984fcea998a93738e69635a838c0f7a8ee3b92b"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/trackfetch/trackfetch/releases/download/v2.3.4/trackfetch-linux-arm64"
      sha256 "d58ef99c3843800707423f78ce9c4ccca33c9fc5dd05086dd22af4ef95b541f9"
    end

    on_intel do
      url "https://github.com/trackfetch/trackfetch/releases/download/v2.3.4/trackfetch-linux-x86_64"
      sha256 "53df9d2d1cb148d7216d6f97434db8cad97349e4ba60de3556dea50c7c215734"
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
