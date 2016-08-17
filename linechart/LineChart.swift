


import UIKit
import QuartzCore

// delegate method
public protocol LineChartDelegate {
    func didSelectDataPoint(columnIndex index: Int, x: CGFloat, yValues: [CGFloat])
}

/**
 * LineChart
 */
public class LineChart: UIView {
    
    /**
    * Helpers class
    */
    private class Helpers {

        /**
        * Lighten color.
        */
        private class func lightenUIColor(color: UIColor) -> UIColor {
            var h: CGFloat = 0
            var s: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 0
            color.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            return UIColor(hue: h, saturation: s, brightness: b * 1.5, alpha: a)
        }
    }
    
    public struct Labels {
        public var visible: Bool = true
        public var values: [String] = []
        public var textColor: UIColor = UIColor.blackColor()
    }
    
    public struct Grid {
        public var visible: Bool = true
        public var count: CGFloat = 10
        // #eeeeee
        public var color: UIColor = UIColor(red: 238/255.0, green: 238/255.0, blue: 238/255.0, alpha: 1)
    }
    
    public struct Axis {
        public var visible: Bool = true
        // #607d8b
        public var color: UIColor = UIColor(red: 96/255.0, green: 125/255.0, blue: 139/255.0, alpha: 1)
        public var inset: CGFloat = 15
    }
    
    public struct Coordinate {
        // public
        public var labels: Labels = Labels()
        public var grid: Grid = Grid()
        public var axis: Axis = Axis()
        
        // private
        private var linear: LinearScale!
        private var scale: ((CGFloat) -> CGFloat)!
        private var invert: ((CGFloat) -> CGFloat)!
        private var ticks: (CGFloat, CGFloat, CGFloat)!
    }
    
    public struct Animation {
        public var enabled: Bool = true
        public var duration: CFTimeInterval = 1
    }
    
    public struct Dots {
        public var visible: Bool = true
        public var color: UIColor = UIColor.whiteColor()
        public var innerRadius: CGFloat = 8
        public var outerRadius: CGFloat = 12
        public var innerRadiusHighlighted: CGFloat = 8
        public var outerRadiusHighlighted: CGFloat = 12
    }
    
    public struct HighlightLine {
        public var visible: Bool = true
        public var lineWidth: CGFloat = 0.5
        public var color: UIColor = UIColor.grayColor()
    }
    
    // default configuration
    public var area: Bool = true
    public var animation: Animation = Animation()
    public var dots: Dots = Dots()
    public var lineWidth: CGFloat = 2
    public var highlightLine: HighlightLine = HighlightLine()
    public var labelFont: UIFont = .preferredFontForTextStyle(UIFontTextStyleCaption2)
    /// Replace big numbers with -k and -m prefixed on Y axis
    public var shortenBigNumsOnYAxis: Bool = false
    
    public var x: Coordinate = Coordinate()
    public var y: Coordinate = Coordinate()

    /// Used to move lines from chart edges
    public var chartInnerMargin: CGFloat = 0.0
    
    // values calculated on init
    private var drawingHeight: CGFloat = 0 {
        didSet {
            let max = getMaximumValue()
            let min = getMinimumValue()
            y.linear = LinearScale(domain: [min, max], range: [chartInnerMargin, drawingHeight - chartInnerMargin * 2])
            y.scale = y.linear.scale()
            y.ticks = y.linear.ticks(Int(y.grid.count))
        }
    }
    private var drawingWidth: CGFloat = 0 {
        didSet {
            let data = dataStore[0]
            x.linear = LinearScale(domain: [0.0, CGFloat(data.count - 1)], range: [chartInnerMargin, drawingWidth - chartInnerMargin * 2])
            x.scale = x.linear.scale()
            x.invert = x.linear.invert()
            x.ticks = x.linear.ticks(Int(x.grid.count))
        }
    }

    public var delegate: LineChartDelegate?
    
    // data stores
    private var dataStore: [[CGFloat]] = []
    private var dotsDataStore: [[DotCALayer]] = []
    private var lineLayerStore: [CAShapeLayer] = []

    private var chartMargins: UIEdgeInsets = UIEdgeInsets()

    private var removeAll: Bool = false
    
    // category10 colors from d3 - https://github.com/mbostock/d3/wiki/Ordinal-Scales
    public var colors: [UIColor] = [
        UIColor(red: 0.121569, green: 0.466667, blue: 0.705882, alpha: 1),
        UIColor(red: 1, green: 0.498039, blue: 0.054902, alpha: 1),
        UIColor(red: 0.172549, green: 0.627451, blue: 0.172549, alpha: 1),
        UIColor(red: 0.839216, green: 0.152941, blue: 0.156863, alpha: 1),
        UIColor(red: 0.580392, green: 0.403922, blue: 0.741176, alpha: 1),
        UIColor(red: 0.54902, green: 0.337255, blue: 0.294118, alpha: 1),
        UIColor(red: 0.890196, green: 0.466667, blue: 0.760784, alpha: 1),
        UIColor(red: 0.498039, green: 0.498039, blue: 0.498039, alpha: 1),
        UIColor(red: 0.737255, green: 0.741176, blue: 0.133333, alpha: 1),
        UIColor(red: 0.0901961, green: 0.745098, blue: 0.811765, alpha: 1)
    ]
    /// Color for chart grid background color, default – nil, no color
    public var chartBackgroundColor: UIColor? = nil
    
    private var highlightShapeLayer: CAShapeLayer!
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = UIColor.clearColor()
    }

    convenience init() {
        self.init(frame: CGRectZero)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override public func drawRect(rect: CGRect) {
        
        if removeAll {
            #if swift(>=2.3)
                let context = UIGraphicsGetCurrentContext()!
            #else
                let context = UIGraphicsGetCurrentContext()
            #endif
            CGContextClearRect(context, rect)
            return
        }

        drawingHeight = bounds.height - (2 * y.axis.inset)

        var maxYLabelSize = calculateMaxYLabelSize()
        maxYLabelSize.width = max(maxYLabelSize.width, x.axis.inset)
        let leftChartMargin = maxYLabelSize.width + 8

        chartMargins = UIEdgeInsets(top: y.axis.inset, left: leftChartMargin, bottom: y.axis.inset, right: x.axis.inset)

        drawingWidth = bounds.width - chartMargins.left - chartMargins.right
        
        // remove all labels
        for view in subviews {
            view.removeFromSuperview()
        }
        
        // remove all lines on device rotation
        for lineLayer in lineLayerStore {
            lineLayer.removeFromSuperlayer()
        }
        lineLayerStore.removeAll()
        
        // remove all dots on device rotation
        for dotsData in dotsDataStore {
            for dot in dotsData {
                dot.removeFromSuperlayer()
            }
        }
        dotsDataStore.removeAll()

        if let bgColor = chartBackgroundColor {
            fillChartBackground(withColor: bgColor)
        }
        
        // draw grid
        if x.grid.visible && y.grid.visible { drawGrid() }
        
        // draw axes
        if x.axis.visible && y.axis.visible { drawAxes() }
        
        // draw labels
        if x.labels.visible { drawXLabels() }
        if y.labels.visible { drawYLabels(maxYLabelSize) }
        
        // draw lines
        for (lineIndex, _) in dataStore.enumerate() {
            
            drawLine(lineIndex)
            
            // draw dots
            if dots.visible { drawDataDots(lineIndex) }
            
            // draw area under line chart
            if area { drawAreaBeneathLineChart(lineIndex) }
            
        }
        
    }
    
    
    
    /**
     * Get y value for given x value. Or return zero or maximum value.
     */
    private func getYValuesForXValue(x: Int) -> [CGFloat] {
        var result: [CGFloat] = []
        for lineData in dataStore {
            if x < 0 {
                result.append(lineData[0])
            } else if x > lineData.count - 1 {
                result.append(lineData[lineData.count - 1])
            } else {
                result.append(lineData[x])
            }
        }
        return result
    }
    
    
    // MARK: - Data points selection
    /**
     * Handle touch events.
     */
    private func handleTouchEvents(touches: Set<UITouch>, event: UIEvent) {
        guard !dataStore.isEmpty else {
            return
        }
        let xValue = touches.first!.locationInView(self).x
        let inverted = x.invert(xValue - chartMargins.left)
        var columnIndex = Int(round(inverted))

        if dataStore[0].count <= columnIndex {
            // Clicked out of scope
            columnIndex = dataStore[0].count - 1
        }

        drawHighlightLine(xValue)

        selectDataPoint(atIndex: columnIndex)
    }

    /// Selects points for passed column index and calls delegate method, if callDelegate arg is true, 
    ///   as if user tapped on a data point
    public func selectDataPoint(atIndex columnIndex: Int, callDelegate: Bool = true) {
        let yValues: [CGFloat] = getYValuesForXValue(columnIndex)
        highlightDataPoints(columnIndex)
        delegate?.didSelectDataPoint(columnIndex: columnIndex, x: xPoint(forColumn: CGFloat(columnIndex)), yValues: yValues)
    }

    /// Marks previously selected points as not selected
    public func deselectDataPoint(atIndex index: Int) {
        for (lineIndex, dotsData) in dotsDataStore.enumerate() {
            // make all dots white again
            for (columnIndex, dotLayer) in dotsData.enumerate() {
                drawDot(layer: dotLayer, lineIndex: lineIndex, columnIndex: columnIndex)
            }
        }
    }
    
    /**
     * Listen on touch end event.
     */
    override public func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        handleTouchEvents(touches, event: event!)
        if let highlightLayer = highlightShapeLayer {
            highlightLayer.removeFromSuperlayer()
        }
    }
    
    
    
    /**
     * Listen on touch move event
     */
    override public func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        handleTouchEvents(touches, event: event!)
    }
    
    
    
    /**
     * Highlight data points at index.
     */
    private func highlightDataPoints(index: Int) {
        for (lineIndex, dotsData) in dotsDataStore.enumerate() {
            // make all dots white again
            for (columnIndex, dotLayer) in dotsData.enumerate() {
                drawDot(layer: dotLayer, lineIndex: lineIndex, columnIndex: columnIndex)
            }
            // highlight current data point
            let columnIndex: Int
            if index < 0 {
                columnIndex = 0
            } else if index > dotsData.count - 1 {
                columnIndex = dotsData.count - 1
            } else {
                columnIndex = index
            }
            let dotLayer = dotsData[columnIndex]
            drawDot(layer: dotLayer, lineIndex: lineIndex, columnIndex: columnIndex, highlighted: true)
        }
    }
    
    /**
     * Draw higlighLine at left position
     */
    private func drawHighlightLine(left: CGFloat) {
        if (highlightLine.visible) {
            let height = self.bounds.height
            let width = self.bounds.width
            var xPosition = left
            
            if left > (width - chartMargins.right) {
                xPosition = width - chartMargins.right
            }

            if (left < chartMargins.left + chartInnerMargin) {
                xPosition = chartMargins.left + chartInnerMargin
            }

            if let highlightLayer = highlightShapeLayer {
                // Use line already created
                let path = CGPathCreateMutable()
                
                CGPathMoveToPoint(path, nil, xPosition, chartMargins.top)
                CGPathAddLineToPoint(path, nil, xPosition, height - chartMargins.bottom - chartInnerMargin)
                highlightLayer.path = path
                
                if (layer.sublayers?.contains(highlightLayer) == false) {
                    layer.addSublayer(highlightLayer)
                }
            } else {
                // Create the line
                let path = CGPathCreateMutable()
                
                CGPathMoveToPoint(path, nil, xPosition, chartMargins.top)
                CGPathAddLineToPoint(path, nil, xPosition, height - chartMargins.bottom - chartInnerMargin)
                
                let highlightLayer = CAShapeLayer()
                highlightLayer.frame = self.bounds
                highlightLayer.path = path
                highlightLayer.strokeColor = highlightLine.color.CGColor
                highlightLayer.fillColor = nil
                highlightLayer.lineWidth = highlightLine.lineWidth
                
                highlightShapeLayer = highlightLayer
                layer.addSublayer(highlightLayer)
                lineLayerStore.append(highlightLayer)
            }
        }
    }

    // MARK: -
    /**
     * Fill chart background with solid color
     */
    private func fillChartBackground(withColor color: UIColor) {
        color.setFill()

        let chartRect = CGRect(x: chartMargins.left, y: chartMargins.top, width: drawingWidth, height: drawingHeight)
        let path = UIBezierPath(rect: chartRect)
        path.fill()
    }


    /**
     * Draw small dot at every data point.
     */
    private func drawDataDots(lineIndex: Int) {
        var dotLayers: [DotCALayer] = []
        
        for index in 0..<dataStore[lineIndex].count {
            
            // draw custom layer with another layer in the center
            let dotLayer = DotCALayer()

            drawDot(layer: dotLayer, lineIndex: lineIndex, columnIndex: index)

            layer.addSublayer(dotLayer)
            dotLayers.append(dotLayer)
            
            // animate opacity
            if animation.enabled {
                let anim = CABasicAnimation(keyPath: "opacity")
                anim.duration = animation.duration
                anim.fromValue = 0
                anim.toValue = 1
                dotLayer.addAnimation(anim, forKey: "opacity")
            }
            
        }
        dotsDataStore.append(dotLayers)
    }

    private func drawDot(layer dotLayer: DotCALayer, lineIndex: Int, columnIndex index: Int, highlighted: Bool = false) {
        dotLayer.sublayers?.forEach({ $0.removeFromSuperlayer() })

        let outerRadius = highlighted ? dots.outerRadiusHighlighted : dots.outerRadius

        let xValue = x.scale(CGFloat(index)) + chartMargins.left + chartInnerMargin - outerRadius/2
        let yValue = bounds.height - y.scale(dataStore[lineIndex][index]) - chartMargins.bottom - chartInnerMargin - outerRadius/2

        dotLayer.dotInnerColor = colors[lineIndex]
        dotLayer.innerRadius = highlighted ? dots.innerRadiusHighlighted : dots.innerRadius
        dotLayer.backgroundColor = (highlighted ? Helpers.lightenUIColor(dotLayer.dotInnerColor) : dots.color).CGColor
        dotLayer.cornerRadius = outerRadius / 2
        dotLayer.frame = CGRect(x: xValue, y: yValue, width: outerRadius, height: outerRadius)
    }


    /**
     * Draw x and y axis.
     */
    private func drawAxes() {
        let path = UIBezierPath()
        // draw x-axis
        x.axis.color.setStroke()
        let y0 = bounds.height - y.scale(0) - chartMargins.bottom
        path.moveToPoint(CGPoint(x: chartMargins.left, y: y0))
        path.addLineToPoint(CGPoint(x: bounds.width - chartMargins.right, y: y0))
        path.stroke()
        // draw y-axis
        y.axis.color.setStroke()
        path.moveToPoint(CGPoint(x: chartMargins.left, y: bounds.height - chartMargins.bottom))
        path.addLineToPoint(CGPoint(x: chartMargins.left, y: chartMargins.top))
        path.stroke()
    }
    
    
    
    /**
     * Get maximum value in all arrays in data store.
     */
    private func getMaximumValue() -> CGFloat {
        var max: CGFloat = 1
        for data in dataStore {
            let newMax = data.maxElement()!
            if newMax > max {
                max = newMax
            }
        }
        return max
    }
    
    
    
    /**
     * Get maximum value in all arrays in data store.
     */
    private func getMinimumValue() -> CGFloat {
        var min: CGFloat = 0
        for data in dataStore {
            let newMin = data.minElement()!
            if newMin < min {
                min = newMin
            }
        }
        return min
    }
    
    
    
    /**
     * Draw line.
     */
    private func drawLine(lineIndex: Int) {
        
        var data = self.dataStore[lineIndex]
        let path = UIBezierPath()
        
        var xValue = x.scale(0) + chartMargins.left + chartInnerMargin
        var yValue = bounds.height - y.scale(data[0]) - chartMargins.bottom - chartInnerMargin
        path.moveToPoint(CGPoint(x: xValue, y: yValue))
        for index in 1..<data.count {
            xValue = x.scale(CGFloat(index)) + chartMargins.left + chartInnerMargin
            yValue = bounds.height - y.scale(data[index]) - chartMargins.bottom - chartInnerMargin
            path.addLineToPoint(CGPoint(x: xValue, y: yValue))
        }
        
        let layer = CAShapeLayer()
        layer.frame = self.bounds
        layer.path = path.CGPath
        layer.strokeColor = colors[lineIndex].CGColor
        layer.fillColor = nil
        layer.lineWidth = lineWidth
        self.layer.addSublayer(layer)
        
        // animate line drawing
        if animation.enabled {
            let anim = CABasicAnimation(keyPath: "strokeEnd")
            anim.duration = animation.duration
            anim.fromValue = 0
            anim.toValue = 1
            layer.addAnimation(anim, forKey: "strokeEnd")
        }
        
        // add line layer to store
        lineLayerStore.append(layer)
    }
    
    
    
    /**
     * Fill area between line chart and x-axis.
     */
    private func drawAreaBeneathLineChart(lineIndex: Int) {
        
        var data = self.dataStore[lineIndex]
        let path = UIBezierPath()
        
        colors[lineIndex].colorWithAlphaComponent(0.2).setFill()
        // move to origin
        path.moveToPoint(CGPoint(x: chartMargins.left + chartInnerMargin, y: bounds.height - y.scale(0) - chartMargins.bottom - chartInnerMargin))
        // add line to first data point
        path.addLineToPoint(CGPoint(x: chartMargins.left + chartInnerMargin, y: bounds.height - y.scale(data[0]) - chartMargins.bottom - chartInnerMargin))
        // draw whole line chart
        for index in 1..<data.count {
            let x1 = x.scale(CGFloat(index)) + chartMargins.left + chartInnerMargin
            let y1 = bounds.height - y.scale(data[index]) - chartMargins.bottom - chartInnerMargin
            path.addLineToPoint(CGPoint(x: x1, y: y1))
        }
        // move down to x axis
        path.addLineToPoint(CGPoint(x: x.scale(CGFloat(data.count - 1)) + chartMargins.left + chartInnerMargin, y: bounds.height - y.scale(0) - chartMargins.bottom - chartInnerMargin))
        // move to origin
        path.addLineToPoint(CGPoint(x: chartMargins.left + chartInnerMargin, y: bounds.height - y.scale(0) - chartMargins.bottom - chartInnerMargin))
        path.fill()
    }
    
    
    
    /**
     * Draw x grid.
     */
    private func drawXGrid() {
        x.grid.color.setStroke()
        let path = UIBezierPath()
        var x1: CGFloat
        let y1: CGFloat = bounds.height - chartMargins.bottom
        let y2: CGFloat = chartMargins.top
        let (start, stop, step) = x.ticks
        for i in start.stride(through: stop, by: step) {
            x1 = xPoint(forColumn: i)
            path.moveToPoint(CGPoint(x: x1, y: y1))
            path.addLineToPoint(CGPoint(x: x1, y: y2))
        }
        path.stroke()
    }

    /// Returns X position of X axis for passed column index
    private func xPoint(forColumn columnIndex: CGFloat) -> CGFloat {
        return x.scale(columnIndex) + chartMargins.left + chartInnerMargin
    }
    
    /**
     * Draw y grid.
     */
    private func drawYGrid() {
        self.y.grid.color.setStroke()
        let path = UIBezierPath()
        let x1: CGFloat = chartMargins.left
        let x2: CGFloat = bounds.width - chartMargins.right
        var y1: CGFloat
        let (start, stop, step) = y.ticks
        for i in start.stride(through: stop, by: step) {
            y1 = bounds.height - y.scale(i) - chartMargins.bottom - chartInnerMargin
            path.moveToPoint(CGPoint(x: x1, y: y1))
            path.addLineToPoint(CGPoint(x: x2, y: y1))
        }
        path.stroke()
    }
    
    
    
    /**
     * Draw grid.
     */
    private func drawGrid() {
        drawXGrid()
        drawYGrid()
    }
    
    
    
    /**
     * Draw x labels.
     */
    private func drawXLabels() {
        let xAxisData = dataStore[0]
        let y = bounds.height - chartMargins.bottom

        let printCustomLabel = (x.labels.values.count > 0)

        let labelWidth = calculateMaxXLabelWidth()

        var prevLabelMaxX: CGFloat?
        for (index, _) in xAxisData.enumerate() {
            let label = UILabel()
            label.font = labelFont
            label.textAlignment = .Center
            label.textColor = x.labels.textColor
            label.text = printCustomLabel ? x.labels.values[index] : String(index)

            let xValue = floor(x.scale(CGFloat(index)) + chartMargins.left + chartInnerMargin - labelWidth / 2)
            if let prev = prevLabelMaxX where prev > xValue {
                // Labels should not overlay so we just skip this one
                continue
            }
            label.frame = CGRect(x: xValue, y: y, width: labelWidth, height: self.y.axis.inset)

            prevLabelMaxX = label.frame.maxX
            addSubview(label)
        }
    }

    /**
     * Calculates max x label width that will be used for all x labels.
     */
    private func calculateMaxXLabelWidth() -> CGFloat {
        return x.labels.values.reduce(0) { (maxWidth, label) -> CGFloat in
            let current = (label as NSString).boundingRectWithSize(CGSize.zero, options: [.UsesLineFragmentOrigin, .UsesFontLeading], attributes: [NSFontAttributeName: labelFont], context: nil)
            if current.size.width > maxWidth {
                return current.size.width
            }
            return maxWidth
        }
    }

    /**
     * Calculates max y label width that will be used to shift left edge of chart to fit all labels.
     */
    private func calculateMaxYLabelSize() -> CGSize {
        let (start, stop, step) = y.ticks
        return start.stride(through: stop, by: step).reduce(.zero) { (maxSize, value) -> CGSize in
            let label = formatYValue(value) as NSString
            let current = label.boundingRectWithSize(CGSize.zero, options: [.UsesLineFragmentOrigin, .UsesFontLeading], attributes: [NSFontAttributeName: labelFont], context: nil)
            if current.size.width > maxSize.width {
                return current.size
            }
            return maxSize
        }
    }
    
    /**
     * Draw y labels.
     */
    private func drawYLabels(labelSize: CGSize) {
        let (start, stop, step) = y.ticks
        for i in start.stride(through: stop, by: step) {
            let yValue = bounds.height - y.scale(i) - chartMargins.bottom - chartInnerMargin - labelSize.height / 2
            let xValue = (chartMargins.left - labelSize.width) / 2
            let label = UILabel(frame: CGRect(x: xValue, y: yValue, width: labelSize.width, height: labelSize.height))
            label.font = labelFont
            label.textAlignment = .Right
            label.text = formatYValue(i)
            label.textColor = y.labels.textColor
            addSubview(label)
        }
    }

    private func formatYValue(value: CGFloat) -> String {
        let source = Float(round(value))
        if shortenBigNumsOnYAxis {
            if source > 1e6 {
                return "\(Int(source / 1e6))M"
            } else if source > 1e3 {
                return "\(Int(source / 1e3))K"
            }
        }
        return String(Int(source))
    }
    
    
    
    /**
     * Add line chart
     */
    public func addLine(data: [CGFloat]) {
        self.dataStore.append(data)
        self.setNeedsDisplay()
    }
    
    
    
    /**
     * Make whole thing white again.
     */
    public func clearAll() {
        self.removeAll = true
        clear()
        self.setNeedsDisplay()
        self.removeAll = false
    }
    
    
    
    /**
     * Remove charts, areas and labels but keep axis and grid.
     */
    public func clear() {
        // clear data
        dataStore.removeAll()
        self.setNeedsDisplay()
    }
}



/**
 * DotCALayer
 */
class DotCALayer: CALayer {
    
    var innerRadius: CGFloat = 8
    var dotInnerColor = UIColor.blackColor()
    
    override init() {
        super.init()
    }
    
    override init(layer: AnyObject) {
        super.init(layer: layer)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func layoutSublayers() {
        super.layoutSublayers()
        let inset = self.bounds.size.width - innerRadius
        let innerDotLayer = CALayer()
        innerDotLayer.frame = CGRectInset(self.bounds, inset/2, inset/2)
        innerDotLayer.backgroundColor = dotInnerColor.CGColor
        innerDotLayer.cornerRadius = innerRadius / 2
        self.addSublayer(innerDotLayer)
    }
    
}



/**
 * LinearScale
 */
public class LinearScale {
    
    var domain: [CGFloat]
    var range: [CGFloat]
    
    public init(domain: [CGFloat] = [0, 1], range: [CGFloat] = [0, 1]) {
        self.domain = domain
        self.range = range
    }
    
    public func scale() -> (x: CGFloat) -> CGFloat {
        return bilinear(domain, range: range, uninterpolate: uninterpolate, interpolate: interpolate)
    }
    
    public func invert() -> (x: CGFloat) -> CGFloat {
        return bilinear(range, range: domain, uninterpolate: uninterpolate, interpolate: interpolate)
    }
    
    public func ticks(m: Int) -> (CGFloat, CGFloat, CGFloat) {
        return scale_linearTicks(domain, m: m)
    }
    
    private func scale_linearTicks(domain: [CGFloat], m: Int) -> (CGFloat, CGFloat, CGFloat) {
        return scale_linearTickRange(domain, m: m)
    }
    
    private func scale_linearTickRange(domain: [CGFloat], m: Int) -> (CGFloat, CGFloat, CGFloat) {
        var extent = scaleExtent(domain)
        let span = extent[1] - extent[0]
        var step = CGFloat(pow(10, floor(log(Double(span) / Double(m)) / M_LN10)))
        let err = CGFloat(m) / span * step
        
        // Filter ticks to get closer to the desired count.
        if (err <= 0.15) {
            step *= 10
        } else if (err <= 0.35) {
            step *= 5
        } else if (err <= 0.75) {
            step *= 2
        }
        
        // Round start and stop values to step interval.
        let start = ceil(extent[0] / step) * step
        let stop = floor(extent[1] / step) * step + step * 0.5 // inclusive
        
        return (start, stop, step)
    }
    
    private func scaleExtent(domain: [CGFloat]) -> [CGFloat] {
        let start = domain[0]
        let stop = domain[domain.count - 1]
        return start < stop ? [start, stop] : [stop, start]
    }
    
    private func interpolate(a: CGFloat, b: CGFloat) -> (c: CGFloat) -> CGFloat {
        var diff = b - a
        func f(c: CGFloat) -> CGFloat {
            return (a + diff) * c
        }
        return f
    }
    
    private func uninterpolate(a: CGFloat, b: CGFloat) -> (c: CGFloat) -> CGFloat {
        var diff = b - a
        var re = diff != 0 ? 1 / diff : 0
        func f(c: CGFloat) -> CGFloat {
            return (c - a) * re
        }
        return f
    }
    
    private func bilinear(domain: [CGFloat], range: [CGFloat], uninterpolate: (a: CGFloat, b: CGFloat) -> (c: CGFloat) -> CGFloat, interpolate: (a: CGFloat, b: CGFloat) -> (c: CGFloat) -> CGFloat) -> (c: CGFloat) -> CGFloat {
        var u: (c: CGFloat) -> CGFloat = uninterpolate(a: domain[0], b: domain[1])
        var i: (c: CGFloat) -> CGFloat = interpolate(a: range[0], b: range[1])
        func f(d: CGFloat) -> CGFloat {
            return i(c: u(c: d))
        }
        return f
    }
    
}
