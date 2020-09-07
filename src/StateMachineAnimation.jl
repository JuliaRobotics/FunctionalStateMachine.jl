@info "FunctionalStateMachine.jl is adding Graphs.jl related tools (Visualization)."

export
  histGraphStateMachineTransitions,
  drawStateTransitionStep,
  drawStateMachineHistory,
  animateStateMachineHistoryByTime,
  animateStateMachineHistoryByTimeCompound,
  animateStateMachineHistoryIntervalCompound

# bad import warning
# import Graphs: incdict
# incdict(::Type{V}, ::Type{E}; is_directed::Bool = true) where {V,E} = incdict(Dict{Int,V}(), E{V}; is_directed=is_directed)

"""
    $SIGNATURES

Create a `Graphs.incdict` object and populate with nodes (states) and edges (transitions)
according to the contents of parameters passed in.

Notes:
- Current implementation repeats duplicate transitions as new edges.
"""
function histGraphStateMachineTransitions(stateVisits, allStates::Vector{Symbol};
                                          maxpenwidth::Real=5, minpenwidth::Real=0.75 )
  #
  g = Graphs.incdict(Dict{Int,Graphs.ExVertex}(), Graphs.ExEdge{Graphs.ExVertex}; is_directed=true)
  # g = Graphs.incdict(Graphs.ExVertex,Graphs.ExEdge,is_directed=true)
  lookup = Dict{Symbol, Int}()

  # add all required states as nodes to the visualization graph
  fid = 0
  for state in allStates
    fid += 1
    lbl = string(state)
    exvert = Graphs.ExVertex(fid, lbl)
    exvert.attributes["label"] = lbl
    Graphs.add_vertex!(g, exvert)
    lookup[state] = fid
  end

  alledges = []

  # add all edges to graph
  maxtransedge = 0
  count = 0
  for (from, tos) in stateVisits
    for to in tos
      count += 1
      exvf = g.vertices[lookup[from]]
      exvt = g.vertices[lookup[to]]
      # add the edge from one to the next state
      # TODO, don't add if already there.
      addedge = true
      for oun in Graphs.out_neighbors(exvf, g)
        if oun.index == exvt.index
          addedge = false 
          # increase penwidth+=1 on that edge
          for ed in Graphs.out_edges(exvf, g)
            ed.attributes["penwidth"] += 1
            # ed.attributes["penwidth"] = minimum([maxpenwidth;ed.attributes["penwidth"]])            
            maxtransedge = maxtransedge < ed.attributes["penwidth"] ? ed.attributes["penwidth"] : maxtransedge
          end
          break
        end
      end
      if addedge
        edge = Graphs.make_edge(g, exvf, exvt)
        edge.attributes["penwidth"] = 1.0
        Graphs.add_edge!(g, edge)
        push!(alledges, edge)
      end
    end
  end

  # normalize edge penwidth to maxpenwidth
  normwidth = maxtransedge/maxpenwidth
  for ed in alledges 
    ed.attributes["penwidth"] = maximum([minpenwidth; ed.attributes["penwidth"]/normwidth])

  end

  return g, lookup
end


function renderStateMachineFrame( vg,
                                  frame::Int;
                                  title::String="",
                                  viewerapp::String="eog",
                                  fext::String="png",
                                  engine::String="dot",
                                  show::Bool=true,
                                  folder::String="fsm_animation",
                                  folderpath = "/tmp/$folder/",
                                  timest::String="",
                                  rmfirst::Bool=false  )
  #
  if rmfirst
    @warn "removing contents of $(folderpath)"
    Base.rm(folderpath, recursive=true, force=true)
  end
  mkpath(folderpath)
  dotfile = "$folderpath/csm_$frame.dot"
  filepath= "$folderpath/csm_$frame.$(fext)"

  # dot file handle
  fid = open(dotfile,"w")
  write(fid,Graphs.to_dot(vg))
  close(fid)

  # build the dot file somewhat manually
  fid = open("$folderpath/dotscript.sh","w")
  str = "head -n `wc -l $dotfile | awk '{print \$1-1}'` $dotfile > $folderpath/tmpdot.dot"
  println(fid, str)
  println(fid, "echo \"graph [label=\\\"$title, $(timest)\\\", labelloc=t];\" >> $folderpath/tmpdot.dot")
  println(fid, "echo \"}\" >> $folderpath/tmpdot.dot")
  close(fid)
  run(`chmod u+x $folderpath/dotscript.sh`)
  run(`sh $folderpath/dotscript.sh`)
  Base.rm(dotfile)
  Base.rm("$folderpath/dotscript.sh")
  run(`mv $folderpath/tmpdot.dot $dotfile`)

  # compile output and maybe show to user
  run(`$(engine) $(dotfile) -T$(fext) -o $(filepath)`)
  show ? (@async run(`$viewerapp $filepath`)) : nothing
  return filepath
end

function setVisGraphOnState!( vg, vertid; 
                              xlabel::String="", 
                              appendxlabel::String="", 
                              vertColor::AbstractString="red" )
  #
  vg.vertices[vertid].attributes["fillcolor"] = vertColor
  vg.vertices[vertid].attributes["style"] = "filled"
  if length(xlabel) > 0
    vg.vertices[vertid].attributes["xlabel"] = xlabel
  end
  if haskey(vg.vertices[vertid].attributes, "xlabel")
    vg.vertices[vertid].attributes["xlabel"] = vg.vertices[vertid].attributes["xlabel"]*appendxlabel
  elseif length(appendxlabel) > 0
    vg.vertices[vertid].attributes["xlabel"] = appendxlabel
  end
end

function clearVisGraphAttributes!(vg)
  for (vid,vert) in vg.vertices
    haskey(vert.attributes, "fillcolor") ? delete!(vert.attributes, "fillcolor") : nothing
    haskey(vert.attributes, "style") ? delete!(vert.attributes, "style") : nothing
    haskey(vert.attributes, "xlabel") ? delete!(vert.attributes, "xlabel") : nothing
  end
  nothing
end

function drawStateTransitionStep( hist,
                                  step::Int,
                                  vg,
                                  lookup::Dict{Symbol,Int};
                                  title::String="",
                                  viewerapp::String="eog",
                                  fext::String="png",
                                  engine::String="dot",
                                  show::Bool=true,
                                  folder::String="",
                                  frame::Int=step,
                                  vertColor::AbstractString="red"  )
  #

  lbl = getStateLabel(hist[step][3])
  vertid = lookup[lbl]
  vert = vg.vertices[vertid]

  fillcolorbefore = haskey(vert.attributes, "fillcolor") ? deepcopy(vg.vertices[vertid].attributes["fillcolor"]) : nothing
  stylebefore = haskey(vert.attributes, "style") ? deepcopy(vg.vertices[vertid].attributes["style"]) : nothing
  xlabelbefore = haskey(vg.vertices[vertid].attributes,"xlabel") ? deepcopy(vg.vertices[vertid].attributes["xlabel"]) : nothing
  # delete!(vert.attributes, "fillcolor")
  # delete!(vert.attributes, "style")

  # identify and set the node
  xlabel = length(title) > 0 ? (xlabelbefore !== nothing ? xlabelbefore*"," : "")*title : ""
  setVisGraphOnState!(vg, vertid, xlabel=xlabel, vertColor=vertColor )

  # render state machine frame
  filepath = renderStateMachineFrame( vg,
                                      frame,
                                      title=title,
                                      viewerapp=viewerapp,
                                      fext=fext,
                                      engine=engine,
                                      show=show,
                                      folder=folder,
                                      timest=string(split(string(hist[step][1]),'T')[end]),
                                      rmfirst=false)
  #

  # clean up the vg structure
  fillcolorbefore === nothing ? delete!(vert.attributes, "fillcolor") : (vert.attributes["fillcolor"]=fillcolorbefore)
  stylebefore === nothing ? delete!(vert.attributes, "style") : (vert.attributes["style"]=stylebefore)
  xlabelbefore === nothing ? delete!(vert.attributes, "xlabel") : (vert.attributes["xlabel"]=xlabelbefore)

  return filepath
end





function drawStateMachineHistory(hist; show::Bool=false, folder::String="" )

  stateVisits, allStates = histStateMachineTransitions(hist)

  vg, lookup = histGraphStateMachineTransitions(stateVisits, allStates)

  for i in 1:length(hist)
    drawStateTransitionStep(hist, i, vg, lookup, folder=folder, show=show  )
  end

  return nothing
end



"""
    $SIGNATURES

Draw simultaneously separate time synchronized frames from each of the desired
state machines.  These images can be produced into synchronous side-by-side videos
which allows for easier debugging and comparison of concurrently running state
machines.
"""
function animateStateMachineHistoryByTime(hist::Vector{Tuple{DateTime, Int, <: Function, T}};
                                          frames::Int=100,
                                          folder="animatestate",
                                          title::String="",
                                          show::Bool=false,
                                          startT=hist[1][1],
                                          stopT=hist[end][1],
                                          rmfirst::Bool=true, 
                                          vertColor::AbstractString="red"  ) where T
  #
  stateVisits, allStates = histStateMachineTransitions(hist)

  vg, lookup = histGraphStateMachineTransitions(stateVisits, allStates)

  totT = stopT - startT
  totT = Millisecond(round(Int, 1.05*totT.value))
  # totT *= 1.05

  step = 1
  len = length(hist)
  @showprogress "exporting state machine images, $title " for i in 1:frames
    aniT = Millisecond(round(Int, i/frames*totT.value)) + startT
    # aniT = i/frames*totT + startT
    if hist[step][1] < aniT && step < len
      step += 1
    end
    drawStateTransitionStep(hist, step, vg, lookup, title=title, folder=folder, show=show, frame=i, vertColor=vertColor  )
  end

  nothing
end

function animateStateMachineHistoryByTimeCompound(hists::Dict{Symbol, Vector{Tuple{DateTime, Int, <: Function, T}}},
                                                  startT,
                                                  stopT;
                                                  frames::Int=100,
                                                  folder="animatestate",
                                                  title::String="",
                                                  show::Bool=false,
                                                  clearstale::Bool=true,
                                                  rmfirst::Bool=true, 
                                                  fsmColors::Dict{Symbol,String}=Dict{Symbol,String}(),
                                                  defaultColor::AbstractString="gray",
                                                  autocolor_cb::Function=(histstep,csym,aniT)->(haskey(fsmColors, csym) ? fsmColors[csym] : defaultColor)  ) where T
  #
  # Dict{Symbol, Vector{Symbol}}
  stateVisits = Dict{Symbol, Vector{Symbol}}()
  allStates = Vector{Symbol}()
  for (csym,hist) in hists
    stateVisits, allStates = histStateMachineTransitions(hist,allStates=allStates, stateVisits=stateVisits  )
  end

  #
  vg, lookup = histGraphStateMachineTransitions(stateVisits, allStates)

  # total draw time and step initialization
  totT = stopT - startT
  totT = Millisecond(round(Int, 1.05*totT.value))
  histsteps = ones(Int, length(hists))

  # clear any stale state
  clearstale ? clearVisGraphAttributes!(vg) : nothing

  # loop across time
  @showprogress "exporting state machine images, $title " for i in 1:frames
    # calc frame time
    aniT = Millisecond(round(Int, i/frames*totT.value)) + startT

    # loop over all state machines
    histidx = 0
    for (csym, hist) in hists
      histidx += 1
      step = histsteps[histidx]
      len = length(hist)
      if hist[step][1] < aniT && step < len
        histsteps[histidx] += 1
      end
      # redefine after +1
      step = histsteps[histidx]

      # modify vg for each history
      lbl = getStateLabel(hist[step][3])
      vertid = lookup[lbl]
      vertColor=autocolor_cb(hist[step], csym, aniT)
      # vertColor=haskey(fsmColors, csym) ? fsmColors[csym] : defaultColor
      setVisGraphOnState!(vg, vertid, appendxlabel=string(csym)*",", vertColor=vertColor )
    end

    # finally render one frame
    renderStateMachineFrame(vg,
                            i,
                            title=title,
                            show=false,
                            folder=folder,
                            timest=string(split(string(aniT),' ')[1]),
                            rmfirst=false  )
    #
    clearVisGraphAttributes!(vg)
  end

end

# count the total number of transitions contained in hists
function getTotalNumberSteps( hists::Dict{Symbol, Vector{Tuple{DateTime, Int, <: Function, T}}} ) where T
  totSteps = 0
  for (whId, hist) in hists, hi in hist
    totSteps += 1
  end
  return totSteps
end

# point to the start step among all history steps
function getFirstStepHist( hists::Dict{Symbol, Vector{Tuple{DateTime, Int, <: Function, T}}} ) where T
  startTime = now()
  maxTime = DateTime(0)
  # NOTE, this whichId=:null is super important to ensure rendering loop can exit properly
  whichId, whichStep = :null, 0
  for (whId, hist) in hists, (st,hi) in enumerate(hist)
    if hi[1] < startTime
      # new starting point indicator
      whichId = whId
      whichStep = st
      startTime = hi[1]
    end
    if maxTime < hi[1]
      maxTime = hi[1]
    end
  end
  return whichId, whichStep, startTime, maxTime
end

# give the next step, closest in time and that has not previously been added to `prevList`.  
# Also update prevList
function getNextStepHist!(hists, 
                          intuple::Tuple{Symbol, Int, DateTime}, 
                          maxTime::DateTime, 
                          prevList::Dict{Symbol, Vector{Int}} )
  #
  oldId, oldStep, oldT = intuple

  whichId, whichStep, newT = :null, 0, maxTime
  for (whId, hist) in hists, (st,hi) in enumerate(hist)
    # make sure all options are populated in previous list tracker
    if !haskey(prevList, whId)  prevList[whId] = Int[]; end
    if oldT < hi[1] && Millisecond(0) <= (hi[1] - oldT) < (newT-oldT) && 
        !(st in prevList[whId])        # must be a different step than before
      # new closest next step
      whichId = whId
      whichStep = st
      newT = hi[1]
    end
  end

  # register this step has previously been taken
  if !haskey(prevList, whichId)  
    prevList[whichId] = Int[]
  end
  push!(prevList[whichId], whichStep)

  return whichId, whichStep, newT
end


# for slower movies, use a slower fps
# run(`ffmpeg -r 10 -i /tmp/caesar/csmCompound/csm_%d.png -c:v libtheora -vf fps=5 -pix_fmt yuv420p -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" -q 10 /tmp/caesar/csmCompound/out.ogv`)
# @async run(`totem /tmp/caesar/csmCompound/out.ogv`)
# draw_more_cb(::Tuple, ::Int, ::String)
function animateStateMachineHistoryIntervalCompound(hists::Dict{Symbol, Vector{Tuple{DateTime, Int, <: Function, T}}};
                                                    easyNames::Dict{Symbol,N}=Dict{Symbol,Nothing}(),
                                                    interval::Int=2,
                                                    folderpath="/tmp/animatestate",
                                                    title::String="",
                                                    show::Bool=false,
                                                    clearstale::Bool=true,
                                                    rmfirst::Bool=true,
                                                    draw_more_cb::Function=(x...)->(), 
                                                    fsmColors::Dict{Symbol,String}=Dict{Symbol,String}(),
                                                    defaultColor::AbstractString="red",
                                                    autocolor_cb::Function=(histstep,csym,aniT)->(haskey(fsmColors, csym) ? fsmColors[csym] : defaultColor)  ) where {T, N}
  #
  # Dict{Symbol, Vector{Symbol}}
  stateVisits = Dict{Symbol, Vector{Symbol}}()
  allStates = Vector{Symbol}()
  for (csym,hist) in hists
    stateVisits, allStates = histStateMachineTransitions(hist,allStates=allStates, stateVisits=stateVisits  )
  end

  #
  vg, lookup = histGraphStateMachineTransitions(stateVisits, allStates)

  # total draw time and step initialization
  # totT = stopT - startT
  # totT = Millisecond(round(Int, 1.05*totT.value))
  # histsteps = ones(Int, length(hists))

  # clear any stale state
  clearstale ? clearVisGraphAttributes!(vg) : nothing

  totSteps = getTotalNumberSteps(hists)
  whId, fsmStep, aniT, maxTime = getFirstStepHist(hists)
  prevList = Dict{Symbol, Vector{Int}}()
  latestList = Dict{Symbol, Int}(whId => fsmStep)

  prevT = aniT
  frameCount = 0
  # loop across time
  @showprogress "exporting state machine images, $title " for stepCount in 1:totSteps
    # which step among the hist fsms is next
    if 1 < stepCount 
      # skip first would-be repeat
      whId, fsmStep, aniT = getNextStepHist!(hists, (whId, fsmStep, aniT), maxTime, prevList)
      latestList[whId] = fsmStep
    end

    # loop over all state "known" machines
    for (csym, lstep) in latestList
      # terminate at end of drawing sequence
      csym == :null ? break : nothing
      # modify vg for each history
      lbl = getStateLabel(hists[csym][lstep][3])
      vertid = lookup[lbl]
      vertColor=autocolor_cb(hists[csym][lstep], csym, aniT)
      easyn = haskey(easyNames, csym) ? easyNames[csym] : csym
      setVisGraphOnState!(vg, vertid, appendxlabel="($easyn.$lstep),", vertColor=vertColor )
    end

    # and draw as many frames for that setup
    for itr in 1:interval
      # increment frame counter
      frameCount += 1
      deltaT = (aniT - prevT).value
      prevT = aniT
      # finally render one frame
      renderStateMachineFrame(vg,
                              frameCount,
                              title=title*" || dt=$deltaT ms ||",
                              show=false,
                              folderpath=folderpath,
                              timest=string(split(string(aniT),' ')[1]),
                              rmfirst=false  )
      #
      # terminate at end of drawing sequence
      whId == :null ? break : nothing
      draw_more_cb(hists[whId][fsmStep], frameCount, folderpath)
    end
    # clear current frame in prep for the next interval
    clearVisGraphAttributes!(vg)
  end

end