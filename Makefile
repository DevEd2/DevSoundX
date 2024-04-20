PROJECTNAME=DevSoundX

%.asm: ;
%.inc: ;
%.bin: ;
$(PROJECTNAME).gb: %.asm %.inc %.bin
	rgbasm -o $(PROJECTNAME).obj -p 255 Main.asm
	rgblink -p 255 -o $(PROJECTNAME).gb -n $(PROJECTNAME).sym $(PROJECTNAME).obj
	rgbfix -v -p 255 $(PROJECTNAME).gb
	rm $(PROJECTNAME).obj

play: $(PROJECTNAME).gb
	/usr/bin/sameboy ./$(PROJECTNAME).gb

clean:
	rm $(PROJECTNAME).gb $(PROJECTNAME).sym
