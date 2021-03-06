/**
 * Created by Nazar on 11.03.2015.
 */
package com.catalystapps.gaf.display;

import flash.errors.Error;
import com.catalystapps.gaf.data.config.CFilter;
import com.catalystapps.gaf.data.config.ICFilterData;
import com.catalystapps.gaf.utils.DisplayUtility;
import com.catalystapps.gaf.utils.FiltersUtility;
import feathers.controls.text.TextFieldTextEditor;
import feathers.utils.geom.MatrixToScaleX;
import feathers.utils.geom.MatrixToScaleY;
import flash.display.BitmapData;
import flash.display3D.Context3DProfile;
import flash.geom.Matrix;
import flash.geom.Rectangle;
import flash.text.TextFormat;
import openfl.filters.BitmapFilter;
import starling.core.Starling;
import starling.display.Image;
import starling.textures.ConcreteTexture;
import starling.textures.Texture;
import starling.utils.MathUtil;

/** @private */
class GAFTextFieldTextEditor extends TextFieldTextEditor
{
	/**
	 * @private
	 */
    private static var HELPER_MATRIX : Matrix = new Matrix();
    
    private var _filters : Array<BitmapFilter>;
    private var _scale : Float;
    private var _csf : Float;
    
    private var _snapshotClipRect : Rectangle;
    
    public function new(scale : Float = 1, csf : Float = 1)
    {
        this._scale = scale;
        this._csf = csf;
        super();
        
        try // Feathers revision before bca9b93
		{
            this._snapshotClipRect = Reflect.field(this, "_textFieldClipRect");
        }
        catch (error : Error)
        {
            this._snapshotClipRect = Reflect.field(this, "_textFieldSnapshotClipRect");
        }
    }
    
    /** @private */
    public function setFilterConfig(value : CFilter, scale : Float = 1) : Void
    {
        var filters : Array<BitmapFilter> = [];
        if (value != null)
        {
            for (filter in value.filterConfigs)
            {
                filters.push(FiltersUtility.getNativeFilter(filter, scale * this._csf));
            }
        }
        
        if (this.textField)
        {
            this.textField.filters = filters;
        }
        else
        {
            this._filters = filters;
        }
    }
    
    /** @private */
    override private function initialize() : Void
    {
        super.initialize();
        
        if (this._filters)
        {
            this.textField.filters = this._filters;
            this._filters = null;
        }
    }
    
	/**
	 * @private
	 */
    override private function refreshSnapshotParameters() : Void
    {
        this._textFieldOffsetX = 0;
        this._textFieldOffsetY = 0;
        this._snapshotClipRect.x = 0;
        this._snapshotClipRect.y = 0;
        
        var clipWidth : Float = this.actualWidth * this._scale * this._csf;
        if (clipWidth < 0)
        {
            clipWidth = 0;
        }
        var clipHeight : Float = this.actualHeight * this._scale * this._csf;
        if (clipHeight < 0)
        {
            clipHeight = 0;
        }
        this._snapshotClipRect.width = clipWidth;
        this._snapshotClipRect.height = clipHeight;
        
        this._snapshotClipRect.copyFrom(DisplayUtility.getBoundsWithFilters(this._snapshotClipRect, this.textField.filters));
        this._textFieldOffsetX = this._snapshotClipRect.x;
        this._textFieldOffsetY = this._snapshotClipRect.y;
        this._snapshotClipRect.x = 0;
        this._snapshotClipRect.y = 0;
    }
    
	/**
	 * @private
	 */
    override private function positionSnapshot() : Void
    {
        if (!this.textSnapshot)
        {
            return;
        }
        
        this.textSnapshot.x = this._textFieldOffsetX / this._scale / this._csf;
        this.textSnapshot.y = this._textFieldOffsetY / this._scale / this._csf;
    }
    
	/**
	 * @private
	 */
    override private function checkIfNewSnapshotIsNeeded() : Void
    {
        var canUseRectangleTexture : Bool = Starling.current.profile != Context3DProfile.BASELINE_CONSTRAINED;
        if (canUseRectangleTexture)
        {
            this._snapshotWidth = this._snapshotClipRect.width;
            this._snapshotHeight = this._snapshotClipRect.height;
        }
        else
        {
            this._snapshotWidth = MathUtil.getNextPowerOfTwo(this._snapshotClipRect.width);
            this._snapshotHeight = MathUtil.getNextPowerOfTwo(this._snapshotClipRect.height);
        }
        var textureRoot : ConcreteTexture = (this.textSnapshot) ? this.textSnapshot.texture.root : null;
        this._needsNewTexture = this._needsNewTexture || !this.textSnapshot ||
                textureRoot.scale != this._scale * this._csf ||
                this._snapshotWidth != textureRoot.width || this._snapshotHeight != textureRoot.height;
    }
    
	/**
	 * @private
	 */
    override private function texture_onRestore() : Void
    {
        if (this.textSnapshot && this.textSnapshot.texture &&
            this.textSnapshot.texture.scale != this._scale * this._csf) 
		{
				//if we've changed between scale factors, we need to recreate
				//the texture to match the new scale factor.
				this.invalidate(INVALIDATION_FLAG_SIZE);
		}
        else
        {
            this.refreshSnapshot();
        }
    }
    
	/**
	 * @private
	 */
    override private function refreshSnapshot() : Void
    {
        if (this._snapshotWidth <= 0 || this._snapshotHeight <= 0)
        {
            return;
        }
        
        var gutterPositionOffset : Float = 2;
        if (this._useGutter)
        {
            gutterPositionOffset = 0;
        }
        
        var textureScaleFactor : Float = this._scale * this._csf;
        
        HELPER_MATRIX.identity();
        HELPER_MATRIX.scale(textureScaleFactor, textureScaleFactor);
        
        HELPER_MATRIX.translate(-this._textFieldOffsetX - gutterPositionOffset, -this._textFieldOffsetY - gutterPositionOffset);
        
        var bitmapData : BitmapData = new BitmapData(this._snapshotWidth, this._snapshotHeight, true, 0x00ff00ff);
        bitmapData.draw(this.textField, HELPER_MATRIX, null, null, this._snapshotClipRect);
        var newTexture : Texture;
        if (!this.textSnapshot || this._needsNewTexture) 
		{
            //skip Texture.fromBitmapData() because we don't want
            //it to create an onRestore function that will be
            //immediately discarded for garbage collection.
            newTexture = Texture.empty(bitmapData.width / textureScaleFactor, bitmapData.height / textureScaleFactor, 
                            true, false, false, textureScaleFactor
                );
            newTexture.root.uploadBitmapData(bitmapData);
            newTexture.root.onRestore = texture_onRestore;
        }
        
        if (!this.textSnapshot)
        {
            this.textSnapshot = new Image(newTexture);
            this.addChild(this.textSnapshot);
        }
        else if (this._needsNewTexture)
        {
            this.textSnapshot.texture.dispose();
            this.textSnapshot.texture = newTexture;
            this.textSnapshot.readjustSize();
        }
        //this is faster, if we haven't resized the bitmapdata
        else
        {
            
            var existingTexture : Texture = this.textSnapshot.texture;
            existingTexture.root.uploadBitmapData(bitmapData);
        }
        
        this.textSnapshot.alpha = (this._text.length > 0) ? 1 : 0;
        bitmapData.dispose();
        this._needsNewTexture = false;
    }
    
    override private function set_textFormat(value : TextFormat) : TextFormat
    {
        this._textFormat = value;
        //since the text format has changed, the comparison will return
        //false whether we use the real previous format or null. might as
        //well remove the reference to an object we don't need anymore.
        this._previousTextFormat = null;
        this.invalidate(INVALIDATION_FLAG_STYLES);
        return value;
    }
}
