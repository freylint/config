{
  description = "KDE Plasma fireplace screensaver wallpaper plugin";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      metadata = pkgs.writeText "metadata.json" ''
        {
          "KPlugin": {
            "Id": "io.lmpriestley.fireplace",
            "Name": "Fireplace",
            "Description": "Animated GLSL fire"
          },
          "X-Plasma-API-Minimum-Version": "6.0",
          "KPackageStructure": "Plasma/Wallpaper"
        }
      '';

      mainQml = pkgs.writeText "main.qml" ''
        import QtQuick
        import org.kde.plasma.plasma5support as P5Support

        Item {
            id: root

            property real _cpuTotal: 0
            property real _cpuIdle: 0
            property real _dskRd: 0
            property real _dskWr: 0
            property string cpuStat: "--%"
            property string gpuStat: "--%"
            property string memStat: "--/--G"
            property string dskStat: "r-- w-- MB/s"

            P5Support.DataSource {
                id: statsSource
                engine: "executable"
                connectedSources: []
                onNewData: function(source, data) {
                    disconnectSource(source)
                    var lines = (data["stdout"] || "").split("\n")
                    for (var i = 0; i < lines.length; i++) {
                        var line = lines[i]
                        if (line.indexOf("CPU:") === 0) {
                            var v = line.slice(4).split(" ")
                            var user=+v[0], nice=+v[1], sys=+v[2], idle=+v[3]
                            var iow=+(v[4]||0), irq=+(v[5]||0), sirq=+(v[6]||0)
                            var total = user+nice+sys+idle+iow+irq+sirq
                            var dT = total - root._cpuTotal, dI = idle - root._cpuIdle
                            if (dT > 0 && root._cpuTotal > 0)
                                root.cpuStat = Math.round((1 - dI/dT)*100) + "%"
                            root._cpuTotal = total
                            root._cpuIdle = idle
                        } else if (line.indexOf("MEM:") === 0) {
                            root.memStat = line.slice(4) + "G"
                        } else if (line.indexOf("GPU:") === 0) {
                            var gv = line.slice(4).trim()
                            root.gpuStat = gv === "--" ? "--%" : gv + "%"
                        } else if (line.indexOf("DSK:") === 0) {
                            var dp = line.slice(4).split(" ")
                            var rd = +dp[0], wr = +dp[1]
                            if (root._dskRd > 0)
                                root.dskStat = "r" + ((rd-root._dskRd)/4096).toFixed(1) + " w" + ((wr-root._dskWr)/4096).toFixed(1) + " MB/s"
                            root._dskRd = rd
                            root._dskWr = wr
                        }
                    }
                }
            }

            ShaderEffect {
                id: shader
                anchors.fill: parent
                property real iTime: 0
                fragmentShader: Qt.resolvedUrl("fireplace.frag.qsb")
            }

            Column {
                id: clock
                spacing: 6

                property real vx: 80
                property real vy: 60

                Component.onCompleted: {
                    x = (root.width  - width)  * 0.45
                    y = (root.height - height) * 0.35
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Rem / K Household"
                    font.family: "monospace"
                    font.pixelSize: 28
                    font.weight: Font.Light
                    color: "#9ba3bc"
                    style: Text.Raised
                    styleColor: "#1a1c24"
                }

                Text {
                    id: timeText
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(new Date(), "hh:mm")
                    font.family: "monospace"
                    font.pixelSize: 80
                    font.weight: Font.Light
                    color: "#dde2f0"
                    style: Text.Raised
                    styleColor: "#1a1c24"
                }

                Text {
                    id: dateText
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(new Date(), "MM/dd/yy")
                    font.family: "monospace"
                    font.pixelSize: 36
                    font.weight: Font.Light
                    color: "#9ba3bc"
                    style: Text.Raised
                    styleColor: "#1a1c24"
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "cpu " + root.cpuStat + "   gpu " + root.gpuStat + "\nmem " + root.memStat + "\ndsk " + root.dskStat
                    font.family: "monospace"
                    font.pixelSize: 20
                    font.weight: Font.Light
                    color: "#9ba3bc"
                    style: Text.Raised
                    styleColor: "#1a1c24"
                    horizontalAlignment: Text.AlignHCenter
                    lineHeight: 1.3
                }
            }

            Timer {
                interval: 16
                running: true
                repeat: true
                onTriggered: {
                    shader.iTime += 0.016
                    fogOverlay.iTime += 0.016
                    timeText.text = Qt.formatDateTime(new Date(), "hh:mm")
                    dateText.text = Qt.formatDateTime(new Date(), "MM/dd/yy")

                    if (clock.width === 0 || root.width === 0) return

                    var nx = clock.x + clock.vx * 0.016
                    var ny = clock.y + clock.vy * 0.016

                    if (nx <= 0)                             { nx = 0;                          clock.vx =  Math.abs(clock.vx) }
                    else if (nx + clock.width >= root.width) { nx = root.width - clock.width;   clock.vx = -Math.abs(clock.vx) }
                    if (ny <= 0)                             { ny = 0;                          clock.vy =  Math.abs(clock.vy) }
                    else if (ny + clock.height >= root.height){ ny = root.height - clock.height; clock.vy = -Math.abs(clock.vy) }

                    clock.x = nx
                    clock.y = ny
                }
            }

            Timer {
                interval: 2000
                running: true
                repeat: true
                triggeredOnStart: true
                onTriggered: {
                    var script = Qt.resolvedUrl("stats.sh").toString().replace(/^file:\/\//, "")
                    statsSource.connectSource("sh " + script)
                }
            }

            // Boat with sheep and bat, scrolling across the lake
            Item {
                id: boatScene
                width: 170
                height: 90
                // Sink the hull ~14px below the waterline
                y: root.height * 0.667 - height + 14

                NumberAnimation on x {
                    from: root.width + 20
                    to: -boatScene.width - 20
                    duration: 128000
                    loops: Animation.Infinite
                    running: true
                }

                // Boat hull: wide flat deck tapering to a curved keel
                Canvas {
                    id: hull
                    width: 140
                    height: 36
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        ctx.beginPath()
                        ctx.moveTo(6, 0)
                        ctx.lineTo(134, 0)
                        ctx.lineTo(126, height - 10)
                        ctx.quadraticCurveTo(70, height + 4, 14, height - 10)
                        ctx.closePath()
                        ctx.fillStyle = "#3b2008"
                        ctx.fill()
                        ctx.strokeStyle = "#8B5e2a"
                        ctx.lineWidth = 2
                        ctx.stroke()
                    }
                }

                // Sheep
                Text {
                    text: "🐑"
                    font.pixelSize: 28
                    anchors.bottom: hull.top
                    anchors.bottomMargin: -4
                    anchors.left: hull.left
                    anchors.leftMargin: 6
                }

                // Bat (holding the fishing rod)
                Text {
                    text: "🦇"
                    font.pixelSize: 26
                    anchors.bottom: hull.top
                    anchors.bottomMargin: -4
                    anchors.left: hull.left
                    anchors.leftMargin: 56
                }

                // Fishing rod
                Rectangle {
                    width: 52
                    height: 2
                    color: "#c8a96e"
                    x: 78
                    y: 28
                    transform: Rotation { angle: -28 }
                }

                // Fishing line
                Rectangle {
                    width: 1
                    height: 50
                    color: "#c0c8d8"
                    opacity: 0.8
                    x: 122
                    y: 8
                }

                // Bobber
                Rectangle {
                    width: 6
                    height: 6
                    radius: 3
                    color: "#dd4422"
                    x: 120
                    y: 58
                }
            }

            // Fog overlay — renders on top of boat/characters
            ShaderEffect {
                id: fogOverlay
                anchors.fill: parent
                property real iTime: 0
                fragmentShader: Qt.resolvedUrl("fog.frag.qsb")
                blending: true
            }
        }
      '';

      fireplaceGlsl = ./fireplace.frag;
      fogGlsl = ./fog.frag;
      statsScript = ./stats.sh;
    in
    {
      packages.${system}.default = pkgs.stdenv.mkDerivation {
        pname = "fireplace-wallpaper";
        version = "1.0";
        dontUnpack = true;
        nativeBuildInputs = [ pkgs.qt6.qtshadertools ];
        dontWrapQtApps = true;
        installPhase = ''
          dest=$out/share/plasma/wallpapers/io.lmpriestley.fireplace
          mkdir -p "$dest/contents/ui"
          cp ${metadata} "$dest/metadata.json"
          cp ${mainQml}  "$dest/contents/ui/main.qml"
          install -m755 ${statsScript} "$dest/contents/ui/stats.sh"
          qsb --glsl '100 es,120,150' --hlsl 50 --msl 12 \
              -o "$dest/contents/ui/fireplace.frag.qsb" \
              ${fireplaceGlsl}
          qsb --glsl '100 es,120,150' --hlsl 50 --msl 12 \
              -o "$dest/contents/ui/fog.frag.qsb" \
              ${fogGlsl}
        '';
      };
    };
}
