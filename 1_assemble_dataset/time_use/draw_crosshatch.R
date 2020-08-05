# downloaded from https://raw.githubusercontent.com/imaddowzimet/drawcrosshatch/master/draw_crosshatch.R
# for use in the data coverage map (see data_coverage_map.R)
# tutorial in this blog post: https://imaddowzimet.github.io/crosshatch/

# Define function
draw.crosshatch <- function(data, width, pattern=c("vertical", "horizontal", "crosshatch")) {
  if (!pattern %in% c("vertical", "horizontal", "crosshatch") ) {
    stop(print("Please specify vertical, horizontal or crosshatch pattern"))
    
  }
  # Our function is going to first find the leftmost and rightmost points
  # of the shapefile piece
  rank_long_right <- row_number(-data$long)
  rank_long_left  <- row_number(data$long)
  leftmostpoint   <- row_number(rank_long_left)      # Pretty sure rows 9 and 10 just duplicate; might want to change this to the actual row number
  rightmostpoint  <- row_number(rank_long_right)

  # Now it's going to create an index of longitudes "width" apart.  
  # if that's not possible, it returns a 1x3 dataframe of NAs:
  if ((data$long[leftmostpoint == 1]+width) >= (data$long[rightmostpoint == 1]- width)) {
    
    lines           <- as.data.frame(matrix(c(NA, NA, NA, NA), 
                                            ncol=4))
    colnames(lines) <- c("x", "y", "xend", "yend")
    
    return(lines)
  
  } else {
  # If it is possible, it returns a vector of longitudes. These will define
  # the horizontal placement of our vertical lines. 
  index_long <- seq(from = (data$long[leftmostpoint==1]  + width), 
                    to   = (data$long[rightmostpoint==1] - .00001), 
                    by   = width )

  # We then need to find the start and end points (in terms of latitude) for each
  # of those vertical lines: 

  # For each longitude in the vector, we want to find the points 
  # immediately to the left and right of that longitude on the 
  # top and bottom of the shape.
  
  # We do so by assuming that the "order" variable goes clockwise (which is convention in most shapefiles)
  # We find the first point that is past index_long, then take the point immediately
  # before it in the order.
  # We then use the slope equation to find latitude at the index_long.
  # (We have to do a bit of renumbering of the order to reflect the fact that there's a "start" number;
  # we renumber so that the start number is the left most point.)

  find.top.lat <- function(index_longitude) {
    
    past_index_long    <- data$long - index_longitude # (positive values are points to the right of the vertical line)
    past_leftmostpoint <- data$order - data$order[leftmostpoint == 1] 
    neworder           <- ifelse(past_leftmostpoint < 0, 
                                 data$order + (max(data$order) - min(data$order) + 1), 
                                 data$order) # This does the renumbering
    data$neworder                 <- neworder
    neworder[past_index_long < 0] <-NA         # We are uninterested in any points to the left of the vertical line
    data$neworderNA               <- neworder
    rightside                     <- data[which.min(data$neworderNA),]            # Find first point to the right of the vertical line
    leftside                      <- data[data$neworder == (rightside$neworder - 1),]  # Find point immediately preceding it          
    
    # Find correct top latitude using slope formula
    long_lat <- leftside$lat + ((index_longitude - leftside$long) * 
                               ((leftside$lat    - rightside$lat) /
                               (leftside$long    - rightside$long)))
    
  }
  
  index_top_lat <- map_dbl(index_long, find.top.lat)

  # For bottom line, do the same thing but backwards, measuring from right most point
  find.bottom.lat <- function(index_longitude) {
    
    past_index_long     <- data$long  - index_longitude  # (negative values are points to the left of the vertical line)
    past_rightmostpoint <- data$order - data$order[rightmostpoint == 1]
    neworder            <- ifelse(past_rightmostpoint < 0, 
                                  data$order + (max(data$order) - min(data$order) + 1), 
                                  data$order)
    data$neworder               <- neworder
    neworder[past_index_long>0] <- NA
    data$neworderNA             <- neworder
    leftside                    <- data[which.min(data$neworderNA),]
    rightside                   <- data[data$neworder==(leftside$neworder-1),]
    
    # Find correct bottom latitude using slope formula
    long_lat <- leftside$lat + ((index_longitude - leftside$long) * 
                               ((leftside$lat    - rightside$lat) /
                               (leftside$long    - rightside$long)))
  }
  
  index_bottom_lat <- map_dbl(index_long, find.bottom.lat) 

  # Output as dataset
  vertical_lines <- as.data.frame(cbind(index_long, index_top_lat, index_long, index_bottom_lat))
  colnames(vertical_lines) <- c("x", "y", "xend", "yend")
  
  } # end of else loop
  
  
  # It's now going to do the same thing to create horizontal lines. 
  # this code is much less commented, to avoid duplication with the code above. 
  rank_lat_top      <- row_number(-data$lat) 
  rank_lat_bottom   <- row_number(data$lat)
  highestpoint      <- row_number(rank_lat_top)
  lowestpoint       <- row_number(rank_lat_bottom)  
  
  # Create an index of latitudes "width" apart.  
  if ((data$lat[lowestpoint == 1]+width) >= (data$lat[highestpoint == 1] - width)) {
    
    lines           <- as.data.frame(matrix(c(NA, NA, NA, NA), 
                                            ncol=4))
    colnames(lines) <- c("x", "y", "xend", "yend")
    return(lines)
    
  } else {
    index_lat <- seq(from = (data$lat[lowestpoint  == 1] + width), 
                      to  = (data$lat[highestpoint == 1] - .000001), 
                      by  = width)  
  
  
    # Find start and end points (in terms of longitudes) for each horizontal line
    
    # Left side:
    
    find.left.long <- function(index_latitude) {
      
      past_index_lat     <- data$lat - index_latitude # (positive values are points above the horizontal line)
      past_lowestpoint   <- data$order - data$order[lowestpoint == 1] 
      neworder           <- ifelse(past_lowestpoint < 0, 
                                   data$order + (max(data$order) - min(data$order) + 1), 
                                   data$order) # This does the renumbering
      
      data$neworder                <- neworder
      neworder[past_index_lat < 0] <-NA         # We are uninterested in any points below the vertical line
      data$neworderNA               <- neworder
      topside                       <- data[which.min(data$neworderNA),]                 # Find first point above vertical line
      bottomside                    <- data[data$neworder == (topside$neworder - 1),]    # Find point immediately below it          
      
      # Find correct top longitude using slope formula
      lat_long <- topside$long +    ((index_latitude - topside$lat) * 
                                    ((topside$long    - bottomside$long) /
                                    (topside$lat    - bottomside$lat)))
      
    }
    
    
    index_left_long <- map_dbl(index_lat, find.left.long)
    
    
    find.right.long <- function(index_latitude) {
      
      past_index_lat      <- data$lat - index_latitude # (negative values are points below the horizontal line)
      past_highestpoint   <- data$order - data$order[highestpoint == 1]
      neworder            <- ifelse(past_highestpoint < 0, 
                                    data$order + (max(data$order) - min(data$order) + 1), 
                                    data$order)
      
      data$neworder              <- neworder
      neworder[past_index_lat>0] <- NA
      data$neworderNA            <- neworder
      bottomside                 <- data[which.min(data$neworderNA),]
      topside                    <- data[data$neworder==(bottomside$neworder-1),]
      
      # Find correct top longitude using slope formula
      lat_long <- topside$long +    ((index_latitude - topside$lat) * 
                                    ((topside$long    - bottomside$long) /
                                    (topside$lat    - bottomside$lat)))
    }
    
    
    index_right_long <- map_dbl(index_lat, find.right.long)
    
    # Output as dataset
    horizontal_lines           <- as.data.frame(cbind(index_left_long, index_lat, index_right_long, index_lat))
    colnames(horizontal_lines) <- c("x", "y", "xend", "yend")
    
    }
  
  if (pattern == "vertical") {
    lines <- vertical_lines 
  }
  if (pattern == "horizontal") {
    lines <- horizontal_lines 
  }
  if (pattern == "crosshatch") {
    lines <- rbind(vertical_lines, horizontal_lines)
  } 

  return(lines)
  
} # end of function