import SwiftUI

struct ColorPickerView: View {
    @Binding var selectedColor: Color
    let onColorSelected: (Color) -> Void
    
    @State private var hue: Double = 0.0
    @State private var saturation: Double = 1.0
    @State private var brightness: Double = 1.0
    @State private var hexInput: String = ""
    
    private let wheelSize: CGFloat = 200
    
    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text("Color Picker")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Color Wheel
            ZStack {
                ColorWheelView(
                    hue: $hue,
                    saturation: $saturation,
                    brightness: $brightness,
                    size: wheelSize
                )
                .frame(width: wheelSize, height: wheelSize)
            }
            
            // Brightness Slider
            VStack(spacing: 4) {
                ZStack {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(hue: hue, saturation: saturation, brightness: 0.35),
                            Color(hue: hue, saturation: saturation, brightness: 1)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 12)
                    .cornerRadius(6)
                    
                    GeometryReader { geometry in
                        Circle()
                            .fill(Color.white)
                            .overlay(Circle().stroke(Color.gray, lineWidth: 1))
                            .frame(width: 16, height: 16)
                            .position(x: CGFloat(nonLinearBrightnessToLinear(brightness)) * geometry.size.width, y: geometry.size.height / 2)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let linearValue = min(max(0, value.location.x / geometry.size.width), 1)
                                        brightness = max(0.35, linearToNonLinearBrightness(linearValue))
                                        updateSelectedColor()
                                    }
                            )
                    }
                }
                .frame(height: 16)
            }
            
            
            // Color Values
            HStack(spacing: 12) {
                // Hex input
                HStack(spacing: 4) {
                    Text("#")
                        .foregroundColor(.secondary)
                    TextField("", text: $hexInput)
                        .textFieldStyle(PlainTextFieldStyle())
                        .frame(width: 70)
                        .onSubmit {
                            updateColorFromHex()
                        }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)
                
                Spacer()
                
                // RGB values
                HStack(spacing: 8) {
                    ColorValueField(value: Int(hue * 360), label: "H")
                    ColorValueField(value: Int(saturation * 100), label: "S")
                    ColorValueField(value: Int(brightness * 100), label: "B")
                }
            }
        }
        .padding(20)
        .frame(width: 300)
        .background(Color(.windowBackgroundColor))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
        .onAppear {
            updateFromColor(selectedColor)
        }
        .onChange(of: hue) { _, _ in updateSelectedColor() }
        .onChange(of: saturation) { _, _ in updateSelectedColor() }
        .onChange(of: brightness) { _, _ in updateSelectedColor() }
    }
    
    private func updateSelectedColor() {
        selectedColor = Color(hue: hue, saturation: saturation, brightness: brightness)
        hexInput = selectedColor.toHex() ?? ""
        // Call the callback immediately for live updates
        onColorSelected(selectedColor)
    }
    
    private func updateFromColor(_ color: Color) {
        let nsColor = NSColor(color)
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else { return }
        
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        rgbColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        
        hue = Double(h)
        saturation = Double(s)
        brightness = Double(b)
        hexInput = color.toHex() ?? ""
    }
    
    private func updateColorFromHex() {
        let color = Color(hex: hexInput)
        updateFromColor(color)
    }
    
    // Convert non-linear brightness (0-1) to linear slider position (0-1)
    // This gives more precision in the bright range (0.5-1.0) and compresses dark range (0-0.5)
    private func nonLinearBrightnessToLinear(_ brightness: Double) -> Double {
        // Use a power curve: y = x^2 for more precision in bright values
        // This maps 0.5 brightness to 0.25 slider position, 0.8 to 0.64, etc.
        return pow(brightness, 2.0)
    }
    
    // Convert linear slider position (0-1) to non-linear brightness (0-1)
    private func linearToNonLinearBrightness(_ linear: Double) -> Double {
        // Inverse of the power curve: y = x^0.5
        // This maps 0.25 slider to 0.5 brightness, 0.64 to 0.8, etc.
        return pow(linear, 0.5)
    }
    
}

// Color Wheel Component
struct ColorWheelView: View {
    @Binding var hue: Double
    @Binding var saturation: Double
    @Binding var brightness: Double
    let size: CGFloat
    
    @State private var dragLocation: CGPoint = .zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Color wheel gradient
                Circle()
                    .fill(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                Color(hue: 0.0, saturation: 1, brightness: 1),
                                Color(hue: 0.1, saturation: 1, brightness: 1),
                                Color(hue: 0.2, saturation: 1, brightness: 1),
                                Color(hue: 0.3, saturation: 1, brightness: 1),
                                Color(hue: 0.4, saturation: 1, brightness: 1),
                                Color(hue: 0.5, saturation: 1, brightness: 1),
                                Color(hue: 0.6, saturation: 1, brightness: 1),
                                Color(hue: 0.7, saturation: 1, brightness: 1),
                                Color(hue: 0.8, saturation: 1, brightness: 1),
                                Color(hue: 0.9, saturation: 1, brightness: 1),
                                Color(hue: 1.0, saturation: 1, brightness: 1)
                            ]),
                            center: .center
                        )
                    )
                
                // Saturation gradient from center (white to transparent)
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.white,
                                Color.white.opacity(0)
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: size / 2
                        )
                    )
                
                // Brightness overlay (darken the whole wheel based on brightness)
                Circle()
                    .fill(Color.black.opacity(1 - brightness))
                
                // Selector circle
                Circle()
                    .fill(Color(hue: hue, saturation: saturation, brightness: brightness))
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                            .shadow(radius: 2)
                    )
                    .position(positionForColor())
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        updateColor(at: value.location, in: geometry.size)
                    }
            )
        }
    }
    
    private func positionForColor() -> CGPoint {
        let radius = size / 2
        let angle = hue * 2 * .pi
        // Apply non-linear mapping to saturation for more precision in desaturated colors
        let nonLinearDistance = pow(saturation, 0.5) * radius
        
        let x = radius + cos(angle) * nonLinearDistance
        let y = radius + sin(angle) * nonLinearDistance  // Changed from - to + to fix vertical inversion
        
        return CGPoint(x: x, y: y)
    }
    
    private func updateColor(at location: CGPoint, in size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y  // Changed from center.y - location.y to fix vertical inversion
        
        let angle = atan2(dy, dx)
        var normalizedAngle = angle / (2 * .pi)
        if normalizedAngle < 0 { normalizedAngle += 1 }
        
        let distance = sqrt(dx * dx + dy * dy)
        let maxRadius = min(size.width, size.height) / 2
        let normalizedDistance = min(distance / maxRadius, 1)
        
        hue = Double(normalizedAngle)
        // Apply inverse non-linear mapping to saturation for more precision in desaturated colors
        saturation = Double(pow(normalizedDistance, 2.0))
    }
}


// Small field for color values
struct ColorValueField: View {
    let value: Int
    let label: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 11, weight: .medium))
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .frame(width: 35)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(6)
    }
}
